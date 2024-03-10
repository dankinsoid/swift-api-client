#if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.

import Foundation

final actor WebSocketStream: AsyncSequence {

	typealias Element = Data
	typealias AsyncIterator = AsyncThrowingStream<Data, Error>.AsyncIterator
	let webSocket: WebSocket
	let pingInterval: Double?
	private var continuations: [UUID: AsyncThrowingStream<Data, Error>.Continuation] = [:]
	private var pingTask: Task<Void, Error>?
	private(set) var isConnected = false
	private(set) var isFinished = false

	init(
		_ webSocket: WebSocket,
		pingInterval: Double?
	) {
		self.webSocket = webSocket
		self.pingInterval = pingInterval
		webSocket.onEvent = didReceive
	}

	nonisolated func makeAsyncIterator() -> AsyncThrowingStream<Data, Error>.AsyncIterator {
		AsyncThrowingStream<Data, Error> { [self] continuation in
			Task {
				await receive(continuation: continuation)
			}
		}
		.makeAsyncIterator()
	}

	func send(_ string: String) async throws {
		try await send {
			$0.write(string: string, completion: $1)
		}
	}

	func send(_ data: Data) async throws {
		try await send {
			$0.write(data: data, completion: $1)
		}
	}

	private func receive(continuation: AsyncThrowingStream<Data, Error>.Continuation) {
		guard !isFinished else {
			continuation.finish()
			return
		}
		let id = UUID()
		continuation.onTermination = { [weak self] _ in
			Task { [self] in
				await self?.onTerminate(id: id)
			}
		}
		continuations[id] = continuation
		guard !isConnected else {
			return
		}
		if let pingInterval {
			pingTask = Task.detached { [weak self, pingInterval] in
				while !Task.isCancelled {
					try await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
					self?.webSocket.write(ping: Data())
				}
			}
		}
		webSocket.connect()
		isConnected = true
	}

	private func finish(throwing error: Error? = nil) {
		guard !isFinished else { return }
		webSocket.onEvent = nil
		isFinished = true
		pingTask?.cancel()
		pingTask = nil
		continuations.forEach { $0.value.finish(throwing: error) }
		continuations = [:]
		webSocket.disconnect()
		isConnected = false
	}

	private func onReceive(data: Data) {
		continuations = continuations.filter {
			switch $0.value.yield(data) {
			case let .enqueued(remaining):
				if remaining > 0 {
					return true
				}
			case .dropped, .terminated:
				break
			@unknown default:
				return true
			}
			$0.value.finish()
			return false
		}
		if continuations.isEmpty {
			finish()
		}
	}

	private func onTerminate(id: UUID) {
		continuations[id] = nil
		if continuations.isEmpty {
			finish()
		}
	}

	private func send(write: (WebSocket, _ completion: (() -> Void)?) throws -> Void) async throws {
		let _: Void = try await withCheckedThrowingContinuation { [self] cont in
			guard isConnected else {
				cont.resume(throwing: Errors.notConnected)
				return
			}
			do {
				try write(webSocket) {
					cont.resume()
				}
			} catch {
				cont.resume(throwing: error)
			}
		}
	}
}

private extension WebSocketStream {

	func didConnect() {
		isConnected = true
	}

	func didDisconnect() {
		finish()
	}

	func viabilityDidChange(isViable: Bool) {}

	func didReceiveError(error: Error?) {
		finish(throwing: error)
	}

	func didReceivePong() {}

	func didReceiveMessage(string: String) {
		didReceiveMessage(data: Data(string.utf8))
	}

	func didReceiveMessage(data: Data) {
		onReceive(data: data)
	}
}

extension WebSocketStream {

	nonisolated func didReceive(event: WebSocketEvent) {
		Task {
			await receive(event: event)
		}
	}

	private func receive(event: WebSocketEvent) {
		switch event {
		case .connected:
			didConnect()
		case .disconnected:
			didDisconnect()
		case let .text(string):
			didReceiveMessage(string: string)
		case let .binary(data):
			didReceiveMessage(data: data)
		case .pong:
			didReceivePong()
		case .ping:
			break
		case let .error(error):
			didReceiveError(error: error)
		case let .viabilityChanged(isViable):
			viabilityDidChange(isViable: isViable)
		case .reconnectSuggested:
			break
		case .cancelled:
			didDisconnect()
		case .peerClosed:
			didDisconnect()
		}
	}
}
#endif
