import Foundation
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A generic structure for handling network requests and their responses.
public struct NetworkClientCaller<Response, Value, Result> {

	private let _call: (
		URLRequest,
		NetworkClient.Configs,
		@escaping (Response, () throws -> Void) throws -> Value
	) throws -> Result
	private let _mockResult: (_ value: Value) throws -> Result

	/// Initializes a new `NetworkClientCaller`.
	/// - Parameters:
	///   - call: A closure that performs the network call.
	///   - mockResult: A closure that handles mock results.
	public init(
		call: @escaping (
			_ request: URLRequest,
			_ configs: NetworkClient.Configs,
			_ serialize: @escaping (Response, _ validate: () throws -> Void) throws -> Value
		) throws -> Result,
		mockResult: @escaping (_ value: Value) throws -> Result
	) {
		_call = call
		_mockResult = mockResult
	}

	/// Performs the network call with the provided request, configurations, and serialization closure.
	/// - Parameters:
	///   - request: The `URLRequest` for the network call.
	///   - configs: The configurations for the network call.
	///   - serialize: A closure that serializes the response.
	/// - Returns: The result of the network call.
	public func call(
		request: URLRequest,
		configs: NetworkClient.Configs,
		serialize: @escaping (Response, _ validate: () throws -> Void) throws -> Value
	) throws -> Result {
		try _call(request, configs, serialize)
	}

	/// Returns a mock result for a given value.
	/// - Parameter value: The value to convert into a mock result.
	/// - Returns: The mock result.
	public func mockResult(for value: Value) throws -> Result {
		try _mockResult(value)
	}

	/// Maps the result to another type using the provided mapper.
	/// - Parameter mapper: A closure that maps the result to a different type.
	/// - Returns: A `NetworkClientCaller` with the mapped result type.
	///
	/// Example
	/// ```swift
	/// try await client.call(.http, as: .decodable)
	/// ```
	public func map<T>(_ mapper: @escaping (Result) throws -> T) -> NetworkClientCaller<Response, Value, T> {
		NetworkClientCaller<Response, Value, T> {
			try mapper(_call($0, $1, $2))
		} mockResult: {
			try mapper(_mockResult($0))
		}
	}
}

public extension NetworkClientCaller where Result == Value {

	/// A caller with a mocked response.
	static func mock(_ response: Response) -> NetworkClientCaller {
		NetworkClientCaller { _, _, serialize in
			try serialize(response) {}
		} mockResult: { value in
			value
		}
	}
}

public extension NetworkClient {

	/// Asynchronously performs a network call using the provided caller and serializer.
	/// - Parameters:
	///   - caller: A `NetworkClientCaller` instance.
	///   - serializer: A `Serializer` to process the response.
	/// - Returns: The result of the network call.
	///
	/// Example
	/// ```swift
	/// let value: SomeModel = try await client.call(.http, as: .decodable)
	/// ```
	func call<Response, Value, Result>(
		_ caller: NetworkClientCaller<Response, Value, AsyncValue<Result>>,
		as serializer: Serializer<Response, Value>,
		fileID: String = #fileID,
		line: UInt = #line
	) async throws -> Result {
		try await call(caller, as: serializer, fileID: fileID, line: line)()
	}

	/// Performs a synchronous network call using the provided caller and serializer.
	/// - Parameters:
	///   - caller: A `NetworkClientCaller` instance.
	///   - serializer: A `Serializer` to process the response.
	/// - Returns: The result of the network call.
	///
	/// Example
	/// ```swift
	/// try client.call(.httpPublisher, as: .decodable).sink { ... }
	/// ```
	func call<Response, Value, Result>(
		_ caller: NetworkClientCaller<Response, Value, Result>,
		as serializer: Serializer<Response, Value>,
		fileID: String = #fileID,
		line: UInt = #line
	) throws -> Result {
		try withRequest { request, configs in
			do {
				configs.logger.debug("Start a request \(request.description)")
				var request = request
				try configs.beforeCall(&request, configs)
				if let mock = try configs.getMockIfNeeded(for: Value.self, serializer: serializer) {
					return try caller.mockResult(for: mock)
				}

				return try caller.call(request: request, configs: configs) { response, validate in
					configs.logger.debug("Response")
					do {
						try validate()
						return try serializer.serialize(response, configs)
					} catch {
						if let data = response as? Data, let failure = configs.errorDecoder.decodeError(data, configs) {
							configs.logger.debug("Response failed with error: `\(error.humanReadable)`")
							throw failure
						}
						throw error
					}
				}
			} catch {
				configs.logger.error("Request \(request.description) failed with error: `\(error.humanReadable)`")
				throw error
			}
		}
	}

	/// Sets a closure to be executed before making a network call.
	///
	/// - Parameters:
	///   - closure: The closure to be executed before making a network call. It takes in an `inout URLRequest` and `NetworkClient.Configs` as parameters and can modify the request.
	/// - Returns: The `NetworkClient` instance.
	func beforeCall(_ closure: @escaping (inout URLRequest, NetworkClient.Configs) throws -> Void) -> NetworkClient {
		configs {
			let beforeCall = $0.beforeCall
			$0.beforeCall = { request, configs in
				try beforeCall(&request, configs)
				try closure(&request, configs)
			}
		}
	}
}

public extension NetworkClient.Configs {

	var beforeCall: (inout URLRequest, NetworkClient.Configs) throws -> Void {
		get { self[\.beforeCall] ?? { _, _ in } }
		set { self[\.beforeCall] = newValue }
	}
}
