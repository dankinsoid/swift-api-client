import Foundation
import HTTPTypes
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct WebSocketPipeline<Element>: AsyncSequence {

	let base: WebSocketChannel
	let serializer: Serializer<Data, Element>
	
	public func makeAsyncIterator() -> AsyncThrowingCompactMapSequence<WebSocketChannel, Element>.Iterator {
		base.compactMap(compactMap).makeAsyncIterator()
	}

	public var publisher: Publishers.TryCompactMap<Publishers.WebSocket, Element> {
		base.publisher.tryCompactMap(compactMap)
	}
	
	public func close(code: WebSocketCloseCode = .goingAway, reason: String? = nil) async throws {
		try await base.close(code: code, reason: reason)
	}
	
	public func ping(payload: Data? = nil) async throws {
		try await base.ping(payload: payload)
	}
	
	public func send(text: String) async throws {
		try await base.send(text: text)
	}
	
	public func send(data: Data) async throws {
		try await base.send(data: data)
	}

	public func send<T>(_ value: T, as serializer: ContentSerializer<T>) async throws {
		try await base.send(value, as: serializer)
	}

	public func send<T: Encodable>(_ value: T) async throws {
		try await send(value, as: .encodable)
	}
	
	private func compactMap(_ message: WebSocketMessage) throws -> Element? {
		switch message {
		case let .text(string):
			guard let data = string.data(using: .utf8) else {
				throw Errors.custom("Invalid UTF-8 string \(string)")
			}
			return try serializer.serialize(data, base.configs)
		case let .binary(data):
			return try serializer.serialize(data, base.configs)
		case .control:
			return nil
		}
	}
}

public final actor WebSocketChannel: AsyncSequence {
	
	public typealias Element = WebSocketMessage

	private let connect: (_ receive: @escaping @Sendable (WebSocketConnectionStreamItem) -> Void) async throws -> WebSocketConnection
	private var connection: WebSocketConnection?
	private var pingPongTask: Task<Void, Error>?
	private var buffers: [UUID: Buffer] = [:]
	private var subscribers: [ObjectIdentifier: (WebSocketConnectionStreamItem) async -> Void] = [:]
	private let pingPongInterval: TimeInterval?
	var isFinished = false
	nonisolated let configs: APIClient.Configs
	
	init(
		pingPongInterval: TimeInterval?,
		configs: APIClient.Configs,
		connect: @escaping (_ receive: @escaping @Sendable (WebSocketConnectionStreamItem) -> Void) async throws -> WebSocketConnection
	) {
		self.pingPongInterval = pingPongInterval
		self.configs = configs
		self.connect = connect
	}

	public nonisolated func makeAsyncIterator() -> AsyncIterator {
		AsyncIterator(base: self)
	}
	
	public func close(code: WebSocketCloseCode = .goingAway, reason: String? = nil) async throws {
		if !isFinished {
			try await connection?.send(.close(code: code, reason: reason))
		}
	}
	
	public func ping(payload: Data? = nil) async throws {
		try await connectIfNeeded().send(.ping(payload: payload))
	}
	
	public func send(text: String) async throws {
		try await connectIfNeeded().send(.text(text))
	}
	
	public func send(data: Data) async throws {
		try await connectIfNeeded().send(.binary(data))
	}

	public func send<T>(_ value: T, as serializer: ContentSerializer<T>) async throws {
		try await connectIfNeeded().send(.binary(serializer.serialize(value, configs)))
	}

	public func send<T: Encodable>(_ value: T) async throws {
		try await send(value, as: .encodable)
	}
	
	public final class AsyncIterator: AsyncIteratorProtocol {
		
		let base: WebSocketChannel
		let id = UUID()
		
		public func next() async throws -> WebSocketMessage? {
			guard !Task.isCancelled, await !base.isFinished else {
				await base.removeBuffer(for: id)
				return nil
			}
			let buffer = await base.buffer(for: id)
			_ = try await base.connectIfNeeded()
			return try await buffer.next()
		}
		
		init(base: WebSocketChannel) {
			self.base = base
		}
		
		deinit {
			Task { [base, id] in
				await base.removeBuffer(for: id)
			}
		}
	}
	
	func buffer(for id: UUID) -> Buffer {
		if let buffer = buffers[id] {
			return buffer
		}
		let buffer = Buffer()
		buffers[id] = buffer
		return buffer
	}
	
	func removeBuffer(for id: UUID) {
		buffers[id] = nil
	}
	
	func addSubscriber(id: ObjectIdentifier, _ subscriber: @escaping (WebSocketConnectionStreamItem) async -> Void) {
		subscribers[id] = subscriber
	}
	
	func removeSubscriber(for id: ObjectIdentifier) {
		subscribers[id] = nil
	}
	
	final actor Buffer {
		
		var items: [WebSocketMessage] = []
		var continuation: CheckedContinuation<WebSocketMessage?, Error>?
		var isClosed = false
		
		func append(_ item: WebSocketMessage) {
			if let continuation {
				self.continuation = nil
				continuation.resume(returning: item)
			} else {
				items.append(item)
			}
		}
		
		func close() {
			isClosed = true
			if let continuation {
				self.continuation = nil
				continuation.resume(returning: nil)
			}
		}
	
		func next() async throws -> WebSocketMessage? {
			if !items.isEmpty {
				return items.removeFirst()
			}
			guard !isClosed else { return nil }
			return try await withCheckedThrowingContinuation { continuation in
				self.continuation = continuation
			}
		}
	}
	
	@discardableResult
	func connectIfNeeded() async throws -> WebSocketConnection {
		if let connection {
			return connection
		}
		if isFinished {
			throw WebSocketClosedError()
		}
		connection = try await connect { [weak self] item in
			guard let self else { return }
			Task {
				for subscriber in await self.subscribers.values {
					await subscriber(item)
				}
				switch item {
				case let .message(webSocketMessage):
					for buffer in await self.buffers.values {
						await buffer.append(webSocketMessage)
					}
				case let .error(error):
					break
				case .closed:
					await self.didFinished()
					for buffer in await self.buffers.values {
						await buffer.close()
					}
				}
			}
		}
		if let pingPongInterval {
			pingPongTask = Task { [weak self] in
				let nanoInterval = UInt64(pingPongInterval * 1_000_000_000)
				while !Task.isCancelled {
					try await Task.sleep(nanoseconds: nanoInterval)
					try? await self?.connection?.send(.ping)
				}
			}
		}
		return connection!
	}

	private func didFinished() {
		isFinished = true
		pingPongTask?.cancel()
		pingPongTask = nil
	}

	deinit {
		pingPongTask?.cancel()
		if let connection {
			Task {
				try await connection.send(.close)
			}
		}
	}
}

struct WebSocketClosedError: LocalizedError {
	var errorDescription: String? { "WebSocket closed" }
}

#if canImport(Combine)
import Combine

extension WebSocketChannel {
	
	public nonisolated var publisher: Publishers.WebSocket {
		Publishers.WebSocket(base: self)
	}
}

extension Publishers {

	public struct WebSocket: Publisher {
		
		public typealias Output = WebSocketMessage
		public typealias Failure = Error
		
		let base: WebSocketChannel
		
		public nonisolated func receive<S>(subscriber: S) where S : Subscriber, Error == S.Failure, WebSocketMessage == S.Input {
			subscriber.receive(subscription: Subscription(subscriber, base: base))
		}
		
		final actor Subscription<S: Subscriber>: Combine.Subscription where S.Input == WebSocketMessage, S.Failure == Error {
			
			nonisolated let subscriber: S
			nonisolated let base: WebSocketChannel
			private var isFinished = false
			
			init(_ subscriber: S, base: WebSocketChannel) {
				self.subscriber = subscriber
				self.base = base
			}
			
			nonisolated func request(_ demand: Subscribers.Demand) {
				Task {
					guard await !base.isFinished else {
						subscriber.receive(completion: .finished)
						await setFinished()
						return
					}
					do {
						await base.addSubscriber(id: ObjectIdentifier(self)) { [weak self] item in
							guard let self, await !self.isFinished else { return }
							switch item {
							case let .message(webSocketMessage):
								_ = subscriber.receive(webSocketMessage)
							case let .error(error):
								break
							case .closed:
								await setFinished()
								cancel()
								subscriber.receive(completion: .finished)
							}
						}
						try await base.connectIfNeeded()
					} catch {
						await setFinished()
						cancel()
						subscriber.receive(completion: .failure(error))
					}
				}
			}
			
			nonisolated func cancel() {
				let id = ObjectIdentifier(self)
				Task { [self] in
					await base.removeSubscriber(for: id)
					if await !isFinished {
						await setFinished()
						subscriber.receive(completion: .finished)
					}
				}
			}
			
			private func setFinished() {
				isFinished = true
			}
			
			deinit {
				let id = ObjectIdentifier(self)
				Task { [base] in
					await base.removeSubscriber(for: id)
				}
			}
		}
	}
}
#endif

public struct WebSocketClient: Sendable {
	
	public var connect: @Sendable (
		HTTPRequestComponents,
		APIClient.Configs,
		_ receive: @escaping @Sendable (WebSocketConnectionStreamItem) -> Void
	) async throws -> WebSocketConnection
	
	public init(
		_ connect: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs, _ receive: @escaping @Sendable (WebSocketConnectionStreamItem) -> Void) async throws -> WebSocketConnection) {
		self.connect = connect
	}
}

extension WebSocketClient {

	static var urlSession: WebSocketClient {
		WebSocketClient { request, configs, receive in
			guard
				let url = request.url,
				let httpRequest = request.request,
				var urlRequest = URLRequest(httpRequest: httpRequest)
			else {
				throw Errors.custom("Invalid request")
			}
			urlRequest.url = url
			let task = configs.urlSession.webSocketTask(with: urlRequest)
			let subscription = Task {
				while !Task.isCancelled {
					do {
						let message = try await task.receive()
						guard !Task.isCancelled else { return }
						switch message {
						case let .data(data):
							receive(.message(.binary(data)))
						case let .string(string):
							receive(.message(.text(string)))
						@unknown default:
							break
						}
					} catch {
						guard !Task.isCancelled else { return }
						if needClose(error) {
							task.cancel(with: .goingAway, reason: nil)
							receive(.closed)
							return
						} else {
							receive(.error(error))
						}
					}
				}
			}
			task.resume()
			
			func needClose(_ error: Error) -> Bool {
				if let error = error as NSError? {
					return error.code == 57 || error.code == 60 || error.code == 54
				}
				return false
			}
			
			return WebSocketConnection { message in
				switch message {
				case let .binary(data):
					try await task.send(.data(data))
				case let .text(string):
					try await task.send(.string(string))
				case let .control(control):
					switch control {
					case let .close(code, reason):
						subscription.cancel()
						if let code {
							task.cancel(
								with: URLSessionWebSocketTask.CloseCode(rawValue: Int(code.rawValue)) ?? .invalid,
								reason: reason?.data(using: .utf8)
							)
						} else {
							task.cancel()
						}
						receive(.closed)
					case let .ping(payload):
						if payload != nil {
							throw Errors.custom("Ping payload is not supported in URLSession")
						}
						task.sendPing { error in
							if let error {
								if needClose(error) {
									subscription.cancel()
									task.cancel(with: .goingAway, reason: nil)
								} else {
									receive(.error(error))
								}
							} else {
								receive(.message(.pong))
							}
						}
					case .pong:
						throw Errors.custom("Manual pong sending is not supported in URLSession")
					}
				}
			}
		}
	}
}

public enum WebSocketConnectionStreamItem {
	
	case message(WebSocketMessage)
	case error(Error)
	case closed
}

public struct WebSocketConnection: Sendable {

	public var send: @Sendable (WebSocketMessage) async throws -> Void

	public init(
		send: @escaping @Sendable (WebSocketMessage) async throws -> Void
	) {
		self.send = send
	}
}

public enum WebSocketMessage: Sendable, Equatable {
	
	case binary(Data)
	case text(String)
	case control(Control)
	
	public enum Control: Sendable, Equatable, Identifiable {
		
		case ping(payload: Data? = nil)
		case pong(payload: Data? = nil)
		case close(code: WebSocketCloseCode?, reason: String? = nil)
		
		public var id: UInt8 { opCode }
		
		public var payload: Data? {
			switch self {
			case let .ping(payload), let .pong(payload):
				return payload
			case let .close(code, reason):
				var data = Data()
				if let code = code {
					var rawValue = code.rawValue.bigEndian
					data.append(Data(bytes: &rawValue, count: MemoryLayout.size(ofValue: rawValue)))
				}
				if let reason = reason {
					data.append(reason.data(using: .utf8) ?? Data())
				}
				return data.isEmpty ? nil : data
			}
		}
		
		public var opCode: UInt8 {
			switch self {
			case .ping:
				return 0x9
			case .pong:
				return 0xA
			case .close:
				return 0x8
			}
		}
	}
	
	public static var ping: WebSocketMessage {
		.control(.ping())
	}

	public static func ping(payload: Data?) -> WebSocketMessage {
		.control(.ping(payload: payload))
	}
	
	public static var pong: WebSocketMessage {
		.control(.pong())
	}
	
	public static func pong(payload: Data?) -> WebSocketMessage {
		.control(.pong(payload: payload))
	}

	public static var close: WebSocketMessage {
		.control(.close(code: .normalClosure))
	}

	public static func close(code: WebSocketCloseCode, reason: String? = nil) -> WebSocketMessage {
		.control(.close(code: code, reason: reason))
	}
}

/// WebSocket close status codes as defined in RFC 6455 Section 7.4
public struct WebSocketCloseCode: RawRepresentable, Sendable, Hashable, Codable, ExpressibleByIntegerLiteral, CodingKeyRepresentable {
	
	public var codingKey: any CodingKey {
		WebSocketCloseCodeCodingKey(intValue: Int(rawValue))
	}
	
	public var rawValue: UInt16
	
	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
	
	public init(integerLiteral value: UInt16) {
		self.rawValue = value
	}
	
	public init?<T>(codingKey: T) where T : CodingKey {
		guard let intValue = codingKey.intValue else { return nil }
		guard (0...65535).contains(intValue) else { return nil }
		self.rawValue = UInt16(intValue)
	}
	
	/// 1000, Successful operation, connection not required anymore
	public static let normalClosure = WebSocketCloseCode(rawValue: 1000)
	
	/// 1001, Browser tab closing, graceful server shutdown
	public static let goingAway = WebSocketCloseCode(rawValue: 1001)
	
	/// 1002, Protocol error, endpoint received malformed frame
	public static let protocolError = WebSocketCloseCode(rawValue: 1002)

	/// 1003, Unsupported data, endpoint received unsupported frame (e.g. binary-only got text frame, ping/pong frames not handled properly)
	public static let unsupportedData = WebSocketCloseCode(rawValue: 1003)

	/// 1004, Reserved, unused
	public static let reserved1004 = WebSocketCloseCode(rawValue: 1004)

	/// 1005, No status received, transport finished without CLOSE frame (e.g. TCP FIN)
	public static let noStatusReceived = WebSocketCloseCode(rawValue: 1005)

	/// 1006, Abnormal closure, transport layer broke (e.g. TCP RST)
	public static let abnormalClosure = WebSocketCloseCode(rawValue: 1006)

	/// 1007, Invalid frame payload data, e.g. malformed UTF-8
	public static let invalidFramePayloadData = WebSocketCloseCode(rawValue: 1007)

	/// 1008, Policy violation, generic code not covered by other errors
	public static let policyViolation = WebSocketCloseCode(rawValue: 1008)

	/// 1009, Message too big, endpoint won’t process large message
	public static let messageTooBig = WebSocketCloseCode(rawValue: 1009)

	/// 1010, Mandatory extension, client required extension not negotiated by server
	public static let mandatoryExtension = WebSocketCloseCode(rawValue: 1010)

	/// 1011, Internal error, unexpected server failure while operating
	public static let internalError = WebSocketCloseCode(rawValue: 1011)

	/// 1012, Service restart, server/service is restarting
	public static let serviceRestart = WebSocketCloseCode(rawValue: 1012)

	/// 1013, Try again later, temporary server condition blocking request
	public static let tryAgainLater = WebSocketCloseCode(rawValue: 1013)

	/// 1014, Bad gateway, server as proxy/gateway got invalid response (HTTP 502)
	public static let badGateway = WebSocketCloseCode(rawValue: 1014)

	/// 1015, TLS handshake failure, transport broke during TLS handshake
	public static let tlsHandshakeFailure = WebSocketCloseCode(rawValue: 1015)

	/// 3000, Unauthorized, application requires authorization (HTTP 401)
	public static let unauthorized = WebSocketCloseCode(rawValue: 3000)

	/// 3003, Forbidden, endpoint lacks permissions (HTTP 403)
	public static let forbidden = WebSocketCloseCode(rawValue: 3003)

	/// 3008, Timeout, endpoint took too long to respond (HTTP 408)
	public static let timeout = WebSocketCloseCode(rawValue: 3008)
	
	private struct WebSocketCloseCodeCodingKey: CodingKey {
		
		var intValue: Int?
		var stringValue: String { "\(intValue ?? -1)" }
		
		init(intValue: Int) {
			self.intValue = intValue
		}
		
		init?(stringValue: String) {
			guard let intValue = Int(stringValue) else { return nil }
			self.intValue = intValue
		}
	}
}
