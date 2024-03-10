#if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.

import Foundation

/// A struct representing an HTTP client capable of performing network requests.
public struct WebSocketClient {
    
    /// A closure that asynchronously retrieves data and an HTTP response for a given URLRequest and network configurations.
    public var stream: (URLRequest, NetworkClient.Configs) throws -> (Data, HTTPURLResponse)
    
    /// Initializes a new `HTTPClient` with a custom data retrieval closure.
    /// - Parameter data: A closure that takes a `URLRequest` and `NetworkClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
    public init(_ stream: @escaping (URLRequest, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse)) {
        self.stream = stream
    }
}

func makeSocket(_ session: URLSession, url: URL) {
    let task = session.webSocketTask(with: url)
    
    task.send(<#T##message: URLSessionWebSocketTask.Message##URLSessionWebSocketTask.Message#>, completionHandler: <#T##((Error)?) -> Void#>)
    task.receive(completionHandler: <#T##(Result<URLSessionWebSocketTask.Message, Error>) -> Void#>)
    task.cancel(with: <#T##URLSessionWebSocketTask.CloseCode#>, reason: <#T##Data?#>)
    task.sendPing(pongReceiveHandler: <#T##(Error?) -> Void#>)

    task.resume()
}

/// Actor which manages a WebSocket connection using `URLSessionWebSocketTask`.
///
/// - Note: This type is currently experimental. There will be breaking changes before the final public release,
///         especially around adoption of the typed throws feature in Swift 6. Please report any missing features or
///         bugs to https://github.com/Alamofire/Alamofire/issues.
@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
final actor WebSocketRequest {

    enum IncomingEvent {
        case connected(protocol: String?)
        case receivedMessage(URLSessionWebSocketTask.Message)
        case disconnected(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
        case completed(Completion)
    }
    
    public struct Event<Success, Failure: Error> {

        public enum Kind {

            case connected(protocol: String?)
            case receivedMessage(Success)
            case serializerFailed(Failure)
            // Only received if the server disconnects or we cancel with code, not if we do a simple cancel or error.
            case disconnected(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?)
            case completed(Completion)
        }
        
        weak var task: WebSocketRequest?
        
        public let kind: Kind
        public var message: Success? {
            guard case let .receivedMessage(message) = kind else { return nil }
            
            return message
        }
        
        init(task: WebSocketRequest, kind: Kind) {
            self.task = task
            self.kind = kind
        }
        
        public func close(sending closeCode: URLSessionWebSocketTask.CloseCode, reason: Data? = nil) {
            task?.close(sending: closeCode, reason: reason)
        }
        
        public func cancel() {
            task?.cancel()
        }
        
        public func sendPing(respondingOn queue: DispatchQueue = .main, onResponse: @escaping (PingResponse) -> Void) {
            task?.sendPing(respondingOn: queue, onResponse: onResponse)
        }
    }
    
    public struct Completion {

        /// Last `URLRequest` issued by the instance.
        public let request: URLRequest?
        /// Last `HTTPURLResponse` received by the instance.
        public let response: HTTPURLResponse?
        /// Last `URLSessionTaskMetrics` produced for the instance.
        public let metrics: URLSessionTaskMetrics?
        /// `Error` produced for the instance, if any.
        public let error: Error?
    }
    
    public struct Configuration {

        public static var `default`: Self { Self() }
        
        public static func `protocol`(_ protocol: String) -> Self {
            Self(protocol: `protocol`)
        }
        
        public static func maximumMessageSize(_ maximumMessageSize: Int) -> Self {
            Self(maximumMessageSize: maximumMessageSize)
        }
        
        public static func pingInterval(_ pingInterval: TimeInterval) -> Self {
            Self(pingInterval: pingInterval)
        }
        
        public let `protocol`: String?
        public let maximumMessageSize: Int
        public let pingInterval: TimeInterval?
        
        init(protocol: String? = nil, maximumMessageSize: Int = 1_048_576, pingInterval: TimeInterval? = nil) {
            self.protocol = `protocol`
            self.maximumMessageSize = maximumMessageSize
            self.pingInterval = pingInterval
        }
    }
    
    /// Response to a sent ping.
    public enum PingResponse {

        public struct Pong {
            let start: Date
            let end: Date
            let latency: TimeInterval
        }
        
        /// Received a pong with the associated state.
        case pong(Pong)
        /// Received an error.
        case error(Error)
        /// Did not send the ping, the request is cancelled or suspended.
        case unsent
    }
    
    struct SocketMutableState {
        var enqueuedSends: [(message: URLSessionWebSocketTask.Message,
                             queue: DispatchQueue,
                             completionHandler: (Result<Void, Error>) -> Void)] = []
        var handlers: [(queue: DispatchQueue, handler: (_ event: IncomingEvent) -> Void)] = []
        var pingTimerItem: DispatchWorkItem?
    }
    
    var state = SocketMutableState()
    var task: URLSessionWebSocketTask?
    
    public let session: URLSession
    public let request: URLRequest
    public let configuration: Configuration
    
    init(
        session: URLSession,
        request: URLRequest,
        configuration: Configuration
    ) {
        self.session = session
        self.request = request
        self.configuration = configuration
    }

    func connect() {
        // TODO: What about the any old tasks? Reset their receive?
        guard task == nil else { return }

        var copiedRequest = request
        let task: URLSessionWebSocketTask
        if let `protocol` = configuration.protocol {
            copiedRequest.headers.update(.websocketProtocol(`protocol`))
            task = session.webSocketTask(with: copiedRequest)
        } else {
            task = session.webSocketTask(with: copiedRequest)
        }
        task.maximumMessageSize = configuration.maximumMessageSize

        self.task = task

        listen(to: task)
        
        guard !state.enqueuedSends.isEmpty else { return }
        
        let sends = state.enqueuedSends
        for send in sends {
            task.send(send.message) { error in
                send.queue.async {
                    if let error {
                        send.completionHandler(.failure(error))
                    } else {
                        send.completionHandler(.success(()))
                    }
                }
            }
        }
        
        state.enqueuedSends = []
    }

    func close(sending closeCode: URLSessionWebSocketTask.CloseCode, reason: Data? = nil) {
        cancelAutomaticPing()
        
        guard state.canTransitionTo(.cancelled) else { return }
        
        state = .cancelled
        
        underlyingQueue.async { self.didClose() }
        
        guard let task = state.tasks.last, task.state != .completed else {
            underlyingQueue.async { self.finish() }
            return
        }
        
        // Resume to ensure metrics are gathered.
        task.resume()
        // Cast from state directly, not the property, otherwise the lock is recursive.
        (state.tasks.last as? URLSessionWebSocketTask)?.cancel(with: closeCode, reason: reason)
        underlyingQueue.async { self.didCancelTask(task) }
    }
    
    private func listen(to task: URLSessionWebSocketTask) {
        // TODO: Do we care about the cycle while receiving?
        task.receive { result in
            switch result {
            case let .success(message):
                for handler in self.state.handlers {
                    // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                    handler.handler(.receivedMessage(message))
                }
                
                self.listen(to: task)
            case .failure:
                // It doesn't seem like any relevant errors are received here, just incorrect garbage, like errors when
                // the task disconnects.
                break
            }
        }
    }

    func didClose() {
        
        // Check whether error is cancellation or other websocket closing error.
        // If so, remove it.
        // Otherwise keep it.
        if let error = state.error, (error as? URLError)?.code == .cancelled {
            state.error = nil
        }
        // TODO: Still issue this event?
        eventMonitor?.requestDidCancel(self)
    }
    

    public func cancel() {
        cancelAutomaticPing()
    }
    
    func didConnect(protocol: String?) {
//        dispatchPrecondition(condition: .onQueue(underlyingQueue))

        // TODO: Capture HTTPURLResponse here too?
        for handler in state.handlers {
            // Saved handler calls out to serializationQueue immediately, then to handler's queue.
            handler.handler(.connected(protocol: `protocol`))
        }
        
        if let pingInterval = configuration.pingInterval {
            startAutomaticPing(every: pingInterval)
        }
    }
    
    public func sendPing(respondingOn queue: DispatchQueue = .main, onResponse: @escaping (PingResponse) -> Void) {
        guard isResumed else {
            queue.async { onResponse(.unsent) }
            return
        }
        
        let start = Date()
        let startTimestamp = ProcessInfo.processInfo.systemUptime
        task?.sendPing { error in
            // Calls back on delegate queue / rootQueue / underlyingQueue
            if let error {
                queue.async {
                    onResponse(.error(error))
                }
                // TODO: What to do with failed ping? Configure for failure, auto retry, or stop pinging?
            } else {
                let end = Date()
                let endTimestamp = ProcessInfo.processInfo.systemUptime
                let pong = PingResponse.Pong(start: start, end: end, latency: endTimestamp - startTimestamp)

                queue.async {
                    onResponse(.pong(pong))
                }
            }
        }
    }
    
    func startAutomaticPing(every pingInterval: TimeInterval) {
        guard isResumed else {
            // Defer out of lock.
            defer { cancelAutomaticPing() }
            return
        }
        
        let item = DispatchWorkItem { [weak self] in
            guard let self, self.isResumed else { return }
            
            self.sendPing(respondingOn: self.underlyingQueue) { response in
                guard case .pong = response else { return }
                
                self.startAutomaticPing(every: pingInterval)
            }
        }
        
        state.pingTimerItem = item
        underlyingQueue.asyncAfter(deadline: .now() + pingInterval, execute: item)
    }
    
#if swift(>=5.8)
    @available(macOS 13, iOS 16, tvOS 16, watchOS 9, *)
    func startAutomaticPing(every duration: Duration) {
        let interval = TimeInterval(duration.components.seconds) + (Double(duration.components.attoseconds) / 1e18)
        startAutomaticPing(every: interval)
    }
#endif
    
    func cancelAutomaticPing() {
        state.pingTimerItem?.cancel()
        state.pingTimerItem = nil
    }
    
    func didDisconnect(closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        dispatchPrecondition(condition: .onQueue(underlyingQueue))
        
        cancelAutomaticPing()
        socketMutableState.read { state in
            for handler in state.handlers {
                // Saved handler calls out to serializationQueue immediately, then to handler's queue.
                handler.handler(.disconnected(closeCode: closeCode, reason: reason))
            }
        }
    }
    
    @discardableResult
    public func streamSerializer<Serializer>(
        _ serializer: Serializer,
        on queue: DispatchQueue = .main,
        handler: @escaping (_ event: Event<Serializer.Output, Serializer.Failure>) -> Void
    ) -> Self where Serializer: WebSocketMessageSerializer, Serializer.Failure == Error {
        forIncomingEvent(on: queue) { incomingEvent in
            let event: Event<Serializer.Output, Serializer.Failure>
            switch incomingEvent {
            case let .connected(`protocol`):
                event = .init(task: self, kind: .connected(protocol: `protocol`))
            case let .receivedMessage(message):
                do {
                    let serializedMessage = try serializer.decode(message)
                    event = .init(task: self, kind: .receivedMessage(serializedMessage))
                } catch {
                    event = .init(task: self, kind: .serializerFailed(error))
                }
            case let .disconnected(closeCode, reason):
                event = .init(task: self, kind: .disconnected(closeCode: closeCode, reason: reason))
            case let .completed(completion):
                event = .init(task: self, kind: .completed(completion))
            }
            
            queue.async { handler(event) }
        }
    }
    
    @discardableResult
    public func streamMessageEvents(
        on queue: DispatchQueue = .main,
        handler: @escaping (_ event: Event<URLSessionWebSocketTask.Message, Never>) -> Void
    ) -> Self {
        forIncomingEvent(on: queue) { incomingEvent in
            let event: Event<URLSessionWebSocketTask.Message, Never>
            switch incomingEvent {
            case let .connected(`protocol`):
                event = .init(task: self, kind: .connected(protocol: `protocol`))
            case let .receivedMessage(message):
                event = .init(task: self, kind: .receivedMessage(message))
            case let .disconnected(closeCode, reason):
                event = .init(task: self, kind: .disconnected(closeCode: closeCode, reason: reason))
            case let .completed(completion):
                event = .init(task: self, kind: .completed(completion))
            }
            
            queue.async { handler(event) }
        }
    }
    
    @discardableResult
    public func streamMessages(
        on queue: DispatchQueue = .main,
        handler: @escaping (_ message: URLSessionWebSocketTask.Message) -> Void
    ) -> Self {
        streamMessageEvents(on: queue) { event in
            event.message.map(handler)
        }
    }
    
    func forIncomingEvent(on queue: DispatchQueue, handler: @escaping (IncomingEvent) -> Void) -> Self {
        socketMutableState.write { state in
            state.handlers.append((queue: queue, handler: { incomingEvent in
                self.serializationQueue.async {
                    handler(incomingEvent)
                }
            }))
        }
        
        appendResponseSerializer {
            self.responseSerializerDidComplete {
                self.serializationQueue.async {
                    handler(.completed(.init(request: self.request,
                                             response: self.response,
                                             metrics: self.metrics,
                                             error: self.error)))
                }
            }
        }
        
        return self
    }
    
    public func send(_ message: URLSessionWebSocketTask.Message,
                     queue: DispatchQueue = .main,
                     completionHandler: @escaping (Result<Void, Error>) -> Void) {
        guard !(isCancelled || isFinished) else { return }
        
        guard let task else {
            // URLSessionWebSocketTask not created yet, enqueue the send.
            socketMutableState.write { state in
                state.enqueuedSends.append((message, queue, completionHandler))
            }
            
            return
        }
        
        task.send(message) { error in
            queue.async {
                completionHandler(Result(value: (), error: error))
            }
        }
    }
}
#endif
