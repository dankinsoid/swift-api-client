import Foundation
import HTTPTypes
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A struct representing an HTTP client capable of performing network requests.
public struct HTTPClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URL request and network configurations.
	public var data: @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (Data, HTTPResponse)

	/// Initializes a new `HTTPClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a URL request and `APIClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(_ data: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (Data, HTTPResponse)) {
		self.data = data
	}
}

extension HTTPClient {

	/// Mocks the client to always return the provided data and response.
	/// - Parameters:
	///   - data: The data to be returned by the mock client.
	///   - response: The HTTP response to be returned by the mock client. Defaults to a 200 OK response.
	/// - Returns: An instance of `HTTPClient` that always returns the specified data and response.
	public static func mock(data: Data, response: HTTPResponse = .init(status: .ok)) -> HTTPClient {
		HTTPClient { request, _ in
			(data, response)
		}
	}

	/// Mocks the client to encode and return the provided encodable object along with the specified response.
	/// - Parameters:
	///   - encodable: The encodable object to be encoded and returned as data. Uses the client's body encoder.
	///   - response: The HTTP response to be returned by the mock client. Defaults to a 200 OK response.
	/// - Returns: An instance of `HTTPClient` that encodes and returns the specified object and response.
	/// - Tip: In order to use a specific encoder, configure the client using `.configs(\.bodyEncoder, encoder)` before applying this mock.
	public static func mock(_ encodable: any Encodable, response: HTTPResponse = .init(status: .ok)) -> HTTPClient {
		HTTPClient { request, configs in
			let data = try configs.bodyEncoder.encode(encodable)
			return (data, response)
		}
	}

	/// Mocks the client to encode and return the provided encodable object along with the specified response status.
	/// - Parameters:
	///   - encodable: The encodable object to be encoded and returned as data. Uses the client's body encoder.
	///   - status: The HTTP status to be used in the response.
	/// - Returns: An instance of `HTTPClient` that encodes and returns the specified object and response.
	/// - Tip: In order to use a specific encoder, configure the client using `.configs(\.bodyEncoder, encoder)` before applying this mock.
	public static func mock(_ encodable: any Encodable, status: HTTPResponse.Status) -> HTTPClient {
		.mock(encodable, response: .init(status: status))
	}

	/// Configures the client with specific configuration values.
	/// - Parameters:
	///   - keyPath: The key path to the configuration property to be modified.
	///   - value: The new value for the specified configuration property.
	/// - Returns: An instance of `APIClient` with updated configurations.
	public func configs<T>(_ keyPath: WritableKeyPath<APIClient.Configs, T>, _ value: T) -> HTTPClient {
		configs {
			$0[keyPath: keyPath] = value
		}
	}

	/// Configures the client with a closure that modifies its configurations.
	/// - Parameter configs: A closure that takes `inout Configs` and modifies them.
	/// - Returns: An instance of `APIClient` with updated configurations.
	public func configs(_ configs: @escaping (inout APIClient.Configs) -> Void) -> HTTPClient {
		HTTPClient { request, currentConfigs in
			var newConfigs = currentConfigs
			configs(&newConfigs)
			return try await self.data(request, newConfigs)
		}
	}
}

public enum RequestBody: Hashable, Sendable {

	case file(URL)
	case data(Data)

	public var data: Data? {
		if case let .data(data) = self {
			return data
		}
		return nil
	}

	public var fileURL: URL? {
		if case let .file(fileURL) = self {
			return fileURL
		}
		return nil
	}
}

public extension APIClient {

	/// Sets a custom HTTP client for the network client.
	/// - Parameter client: The `HTTPClient` to be used for network requests.
	/// - Returns: An instance of `APIClient` configured with the specified HTTP client.
	func httpClient(_ client: HTTPClient) -> APIClient {
		configs(\.httpClient, client)
	}
}

public extension APIClient.Configs {

	/// The HTTP client used for network operations.
	/// Gets the currently set `HTTPClient`, or the default `URLsession`-based client if not set.
	/// Sets a new `HTTPClient`.
	var httpClient: HTTPClient {
		get { self[\.httpClient] ?? .urlSession }
		set { self[\.httpClient] = newValue }
	}
}

public extension APIClientCaller where Result == AsyncThrowingValue<Value>, Response == Data {

	static var http: APIClientCaller {
		APIClientCaller<Data, Value, AsyncThrowingValue<(Value, HTTPResponse)>>
			.httpResponse
			.dropHTTPResponse
	}
}

public extension APIClientCaller where Result == AsyncThrowingValue<(Value, HTTPResponse)>, Response == Data {

	static var httpResponse: APIClientCaller {
		HTTPClientCaller<Data, Value>.http { request, configs in
			let isUpload = request.body != nil
			if isUpload, request.method == .get {
				configs.logger.warning("It is not allowed to add a body in GET request.")
			}
			return try await configs.httpClient.data(request, configs)
		}
		.mapResponse(\.0)
	}
}

extension APIClientCaller where Result == AsyncThrowingValue<(Value, HTTPResponse)>, Response == (Data, HTTPResponse) {

	static func http(
		task: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (Data, HTTPResponse)
	) -> APIClientCaller {
		.http(task: task) {
			try $2.httpResponseValidator.validate($1, $0, $2)
		} data: {
			$0
		}
	}
}

typealias HTTPClientCaller<R, T> = APIClientCaller<(R, HTTPResponse), T, AsyncThrowingValue<(T, HTTPResponse)>>

extension APIClientCaller where Result == AsyncThrowingValue<(Value, HTTPResponse)> {

	var dropHTTPResponse: APIClientCaller<Response, Value, AsyncThrowingValue<Value>> {
		map { asyncCl in
			{ try await asyncCl().0 }
		}
	}
}

extension APIClientCaller where Result == AsyncThrowingValue<(Value, HTTPResponse)> {

	static func http<T>(
		task: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse),
		validate: @escaping (T, HTTPResponse, APIClient.Configs) throws -> Void,
		data: @escaping (T) -> Data?
	) -> APIClientCaller where Response == (T, HTTPResponse) {
		var result = APIClientCaller { uuid, request, configs, serialize in
			{
				let value: T
				let response: HTTPResponse
				let start = Date()
				let responseWrapper = SendableValue<(T, HTTPResponse)?>(nil)
				let requestWrapper = SendableValue(request)
				do {
					(value, response) = try await configs.httpClientMiddleware.execute(request: request, configs: configs) { request, configs in
						configs.logRequestStarted(request, uuid: uuid)
						await requestWrapper.set(request)
						let result = try await task(request, configs)
						configs.listener.onResponseReceived(id: uuid, response: result, configs: configs)
						await responseWrapper.set(result)
						return result
					}
				} catch {
					let request = await requestWrapper.value
					throw configs.logRequestFailed(
						request,
						response: nil,
						data: nil,
						start: start,
						uuid: uuid,
						error: error
					)
				}
				let result = try serialize((value, response)) {
					try validate(value, response, configs)
				}
				configs.listener.onResponseSerialized(id: uuid, response: result, configs: configs)
				await configs.logRequestCompleted(
					requestWrapper.value,
					response: responseWrapper.value?.1,
					data: responseWrapper.value?.0 as? Data,
					uuid: uuid,
					start: start
				)
				return (result, response)
			}
		} mockResult: { value in
			asyncWithResponse(value)
		}
		result.logRequestByItSelf = true
		return result
	}
}

private final actor SendableValue<Value> {

	var value: Value

	init(_ value: Value) {
		self.value = value
	}

	func set(_ value: Value) {
		self.value = value
	}
}

private func asyncWithResponse<T>(_ value: T) -> AsyncThrowingValue<(T, HTTPResponse)> {
	{ (value, HTTPResponse(status: .ok)) }
}
