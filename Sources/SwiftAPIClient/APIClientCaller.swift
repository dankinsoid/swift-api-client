import Foundation
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A generic structure for handling network requests and their responses.
public struct APIClientCaller<Response, Value, Result> {

	var logRequestByItSelf = false
	private let _call: (
		UUID,
		HTTPRequestComponents,
		APIClient.Configs,
		@escaping (Response, () throws -> Void) throws -> Value
	) throws -> Result
	private let _mockResult: (_ value: Value) throws -> Result

	/// Initializes a new `APIClientCaller`.
	/// - Parameters:
	///   - call: A closure that performs the network call.
	///   - mockResult: A closure that handles mock results.
	public init(
		call: @escaping (
			_ uuid: UUID,
			_ request: HTTPRequestComponents,
			_ configs: APIClient.Configs,
			_ serialize: @escaping (Response, _ validate: () throws -> Void) throws -> Value
		) throws -> Result,
		mockResult: @escaping (_ value: Value) throws -> Result
	) {
		_call = call
		_mockResult = mockResult
	}

	/// Performs the network call with the provided request, configurations, and serialization closure.
	/// - Parameters:
	///   - request: The URL request for the network call.
	///   - configs: The configurations for the network call.
	///   - serialize: A closure that serializes the response.
	/// - Returns: The result of the network call.
	public func call(
		uuid: UUID,
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		serialize: @escaping (Response, _ validate: () throws -> Void) throws -> Value
	) throws -> Result {
		try _call(uuid, request, configs, serialize)
	}

	/// Returns a mock result for a given value.
	/// - Parameter value: The value to convert into a mock result.
	/// - Returns: The mock result.
	public func mockResult(for value: Value) throws -> Result {
		try _mockResult(value)
	}

	/// Maps the result to another type using the provided mapper.
	/// - Parameter mapper: A closure that maps the result to a different type.
	/// - Returns: A `APIClientCaller` with the mapped result type.
	///
	/// Example
	/// ```swift
	/// try await client.call(.http, as: .decodable)
	/// ```
	public func map<T>(_ mapper: @escaping (Result) throws -> T) -> APIClientCaller<Response, Value, T> {
		APIClientCaller<Response, Value, T> {
			try mapper(_call($0, $1, $2, $3))
		} mockResult: {
			try mapper(_mockResult($0))
		}
	}

	/// Maps the response to another type using the provided mapper.
	/// - Parameter mapper: A closure that maps the result to a different type.
	/// - Returns: A `APIClientCaller` with the mapped result type.
	///
	/// Example
	/// ```swift
	/// try await client.call(.http, as: .decodable)
	/// ```
	public func mapResponse<T>(_ mapper: @escaping (Response) throws -> T) -> APIClientCaller<T, Value, Result> {
		APIClientCaller<T, Value, Result> { id, request, configs, serialize in
			try _call(id, request, configs) { response, validate in
				try serialize(mapper(response), validate)
			}
		} mockResult: {
			try _mockResult($0)
		}
	}
}

public extension APIClientCaller where Result == Value {
	
	/// A caller with a mocked response.
	static func mock(_ response: Response) -> APIClientCaller {
		APIClientCaller { _, _, _, serialize in
			try serialize(response) {}
		} mockResult: { value in
			value
		}
	}

	/// A caller that maps the request to a response.
	/// - Parameter map: Closure that transforms the request into a response.
	static func mock(
		_ map: @escaping (HTTPRequestComponents) -> Response
	) -> APIClientCaller {
		APIClientCaller { _, request, _, serialize in
			let response = map(request)
			let result =  try serialize(response) {}
			return result
		} mockResult: { value in
			value
		}
	}
}

public extension APIClient {

	/// Asynchronously performs a network call using the provided caller and serializer.
	/// - Parameters:
	///   - caller: A `APIClientCaller` instance.
	///   - serializer: A `Serializer` to process the response.
	/// - Returns: The result of the network call.
	///
	/// Example
	/// ```swift
	/// let value: SomeModel = try await client.call(.http, as: .decodable)
	/// ```
	func call<Response, Value, Result>(
		_ caller: APIClientCaller<Response, Value, AsyncThrowingValue<Result>>,
		as serializer: Serializer<Response, Value>,
		fileID: String = #fileID,
		line: UInt = #line
	) async throws -> Result {
		try await call(caller, as: serializer, fileID: fileID, line: line)()
	}

	/// Asynchronously performs a network call using the provided caller and serializer.
	/// - Parameters:
	///   - caller: A `APIClientCaller` instance.
	/// - Returns: The result of the network call.
	///
	/// Example
	/// ```swift
	/// let url = try await client.call(.httpDownload)
	/// ```
	func call<Value, Result>(
		_ caller: APIClientCaller<Value, Value, AsyncThrowingValue<Result>>,
		fileID: String = #fileID,
		line: UInt = #line
	) async throws -> Result {
		try await call(caller, as: .identity, fileID: fileID, line: line)()
	}

	/// Asynchronously performs a network call using the http caller and decodable serializer.
	/// - Returns: The result of the network call.
	func call<Result: Decodable>(fileID: String = #fileID, line: UInt = #line) async throws -> Result {
		try await call(.http, as: .decodable, fileID: fileID, line: line)
	}

	/// Asynchronously performs a network call using the http caller and decodable serializer.
	/// - Returns: The result of the network call.
	func callAsFunction<Result: Decodable>(fileID: String = #fileID, line: UInt = #line) async throws -> Result {
		try await call(fileID: fileID, line: line)
	}

	/// Asynchronously performs a network call using the http caller and void serializer.
	/// - Returns: The result of the network call.
	func call(fileID: String = #fileID, line: UInt = #line) async throws {
		try await call(.http, as: .void, fileID: fileID, line: line)
	}

	/// Asynchronously performs a network call using the http caller and void serializer.
	/// - Returns: The result of the network call.
	func callAsFunction(fileID: String = #fileID, line: UInt = #line) async throws {
		try await call(fileID: fileID, line: line)
	}

	/// Performs a network call using the provided caller and serializer.
	/// - Parameters:
	///   - caller: A `APIClientCaller` instance.
	/// - Returns: The result of the network call.
	///
	/// Example
	/// ```swift
	/// try client.call(.httpPublisher).sink { data in ... }
	/// ```
	func call<Value, Result>(
		_ caller: APIClientCaller<Value, Value, Result>,
		fileID: String = #fileID,
		line: UInt = #line
	) throws -> Result {
		try call(caller, as: .identity, fileID: fileID, line: line)
	}

	/// Performs a network call using the provided caller and serializer.
	/// - Parameters:
	///   - caller: A `APIClientCaller` instance.
	///   - serializer: A `Serializer` to process the response.
	/// - Returns: The result of the network call.
	///
	/// Example
	/// ```swift
	/// try client.call(.httpPublisher, as: .decodable).sink { ... }
	/// ```
	func call<Response, Value, Result>(
		_ caller: APIClientCaller<Response, Value, Result>,
		as serializer: Serializer<Response, Value>,
		fileID: String = #fileID,
		line: UInt = #line
	) throws -> Result {
		let uuid = UUID()
		do {
			return try withRequest { request, configs in
				let fileIDLine = configs.fileIDLine ?? FileIDLine(fileID: fileID, line: line)
				let configs = configs.with(\.fileIDLine, fileIDLine)

				if let mock = try configs.getMockIfNeeded(for: Value.self, serializer: serializer) {
					#if canImport(Metrics)
					configs.with(\.reportMetrics, false).logRequest(request, uuid: uuid)
					#else
					configs.logRequest(request, uuid: uuid)
					#endif
					let result = try caller.mockResult(for: mock)
					configs.listener.onResponseSerialized(id: uuid, response: result, configs: configs)
					return result
				}

				try configs.requestValidator.validate(request, configs.with(\.requestValidator, .alwaysSuccess))
				if !caller.logRequestByItSelf {
					configs.logRequest(request, uuid: uuid)
				}

				return try caller.call(uuid: uuid, request: request, configs: configs) { response, validate in
					do {
						try validate()
						let result = try serializer.serialize(response, configs)
						#if canImport(Metrics)
						if configs.reportMetrics {
							updateTotalResponseMetrics(for: request, successful: true)
						}
						#endif
						configs.listener.onResponseSerialized(id: uuid, response: result, configs: configs)
						return result
					} catch {
						#if canImport(Metrics)
						if configs.reportMetrics {
							updateTotalResponseMetrics(for: request, successful: false)
						}
						#endif

						let context = APIErrorContext(
							request: request,
							response: response as? Data,
							fileIDLine: fileIDLine
						)
						do {
							if let data = response as? Data, let failure = configs.errorDecoder.decodeError(data, configs) {
								try configs.errorHandler(failure, configs, context)
								throw failure
							}
							try configs.errorHandler(error, configs, context)
							throw error
						} catch {
							configs.listener.onError(id: uuid, error: error, configs: configs)
							throw error
						}
					}
				}
			}
		} catch {
			do {
				try withConfigs { configs in
					let fileIDLine = configs.fileIDLine ?? FileIDLine(fileID: fileID, line: line)
					let configs = configs.with(\.fileIDLine, fileIDLine)
					if !configs._errorLoggingComponents.isEmpty {
						let message = configs._errorLoggingComponents.errorMessage(
							uuid: uuid,
							error: error,
							maskedHeaders: configs.logMaskedHeaders,
							fileIDLine: fileIDLine
						)
						configs.logger.log(level: configs._errorLogLevel, "\(message)")
					}
#if canImport(Metrics)
					if configs.reportMetrics {
						updateTotalErrorsMetrics(for: nil)
					}
#endif
					let context = APIErrorContext(fileIDLine: fileIDLine)
					try configs.errorHandler(error, configs, context)
				}
				throw error
			} catch {
				withConfigs { configs in
					configs.listener.onError(id: uuid, error: error, configs: configs)
				}
				throw error
			}
		}
	}
}
