#if canImport(Darwin) && !canImport(FoundationNetworking) // Only Apple platforms support URLSessionWebSocketTask.
import Foundation

/// A generic `AsyncSequence` for managing data communication over a WebSocket channel.
public struct WebSocketChannel<Element>: AsyncSequence {

	private let sequence: AnyAsyncSequence<Element>
	private let sendData: (Data) async throws -> Void
	private let sendString: (String) async throws -> Void

	/// Initializes a new WebSocket channel with the given async sequence and sending capabilities.
	/// - Parameters:
	///   - sequence: An `AsyncSequence` providing elements of type `Element`.
	///   - sendData: An asynchronous closure for sending `Data`.
	///   - sendString: An asynchronous closure for sending a `String`.
	public init<S: AsyncSequence>(
		_ sequence: S,
		sendData: @escaping (Data) async throws -> Void,
		sendString: @escaping (String) async throws -> Void
	) where S.Element == Element {
		self.sequence = sequence.eraseToAnyAsyncSequence()
		self.sendData = sendData
		self.sendString = sendString
	}

	/// Creates an iterator for the underlying async sequence.
	public func makeAsyncIterator() -> AnyAsyncSequence<Element>.AsyncIterator {
		sequence.makeAsyncIterator()
	}

	/// Sends data over the WebSocket channel.
	/// - Parameter data: The `Data` object to send.
	public func send(_ data: Data) async throws {
		try await sendData(data)
	}

	/// Sends a string over the WebSocket channel.
	/// - Parameter string: The `String` to send.
	public func send(_ string: String) async throws {
		try await sendString(string)
	}

	/// Encodes and sends an `Encodable` value over the WebSocket channel.
	/// - Parameters:
	///   - value: The `Encodable` value to send.
	///   - encoder: The `ContentEncoder` used to encode the value.
	/// - Throws: An error if the value cannot be encoded or if the encoded data is not valid UTF-8.
	public func send(_ value: any Encodable, encoder: some ContentEncoder) async throws {
		guard let string = try String(data: encoder.encode(value), encoding: .utf8) else {
			throw Errors.invalidUTF8Data
		}
		try await sendString(string)
	}

	/// Transforms each element of the channel to a new form.
	/// - Parameter transform: An asynchronous closure that takes an element and returns a transformed value.
	/// - Returns: A `WebSocketChannel` of the transformed type `T`.
	public func map<T>(
		_ transform: @escaping (Element) async throws -> T
	) -> WebSocketChannel<T> {
		WebSocketChannel<T>(
			sequence.map(transform),
			sendData: sendData,
			sendString: sendString
		)
	}
}
#endif
