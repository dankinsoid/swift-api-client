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
						configs.logRequest(request, uuid: uuid)
						await requestWrapper.set(request)
						let result = try await task(request, configs)
						configs.listener.onResponseReceived(id: uuid, response: result, configs: configs)
						await responseWrapper.set(result)
						return result
					}
				} catch {
					let request = await requestWrapper.value
					let response = await responseWrapper.value
					let duration = Date().timeIntervalSince(start)
					if !configs._errorLoggingComponents.isEmpty {
						let message = configs._errorLoggingComponents.errorMessage(
							uuid: uuid,
							error: error,
							request: request,
							duration: duration,
							maskedHeaders: configs.logMaskedHeaders,
							fileIDLine: configs.fileIDLine
						)
						configs.logger.log(level: configs._errorLogLevel, "\(message)")
					}
					#if canImport(Metrics)
					if configs.reportMetrics {
						updateHTTPMetrics(for: request, status: response?.1.status, duration: duration, successful: false)
					}
					#endif
					do {
						try configs.errorHandler(
							error,
							configs,
							APIErrorContext(
								request: request,
								response: response.flatMap { data($0.0) },
								status: response?.1.status,
								fileIDLine: configs.fileIDLine ?? FileIDLine()
							)
						)
						throw error
					} catch {
						configs.listener.onError(id: uuid, error: error, configs: configs)
						throw error
					}
				}
				let request = await requestWrapper.value
				let duration = Date().timeIntervalSince(start)
				let data = data(value)
				do {
					let result = try serialize((value, response)) {
						try validate(value, response, configs)
					}
					let isError = response.status.kind.isError
					let logComponents = isError ? configs._errorLoggingComponents : configs.loggingComponents
					if !logComponents.isEmpty {
						let message = logComponents.responseMessage(
							for: response,
							uuid: uuid,
							request: request,
							data: data,
							duration: duration,
							maskedHeaders: configs.logMaskedHeaders,
							fileIDLine: configs.fileIDLine
						)
						configs.logger.log(
							level: isError ? configs._errorLogLevel : configs.logLevel,
							"\(message)"
						)
					}
					#if canImport(Metrics)
					if configs.reportMetrics {
						updateHTTPMetrics(for: request, status: response.status, duration: duration, successful: true)
					}
					#endif
					return (result, response)
				} catch {
					if !configs._errorLoggingComponents.isEmpty {
						let message = configs._errorLoggingComponents.responseMessage(
							for: response,
							uuid: uuid,
							request: request,
							data: data,
							duration: duration,
							error: error,
							maskedHeaders: configs.logMaskedHeaders,
							fileIDLine: configs.fileIDLine
						)
						configs.logger.log(level: configs._errorLogLevel, "\(message)")
					}
					#if canImport(Metrics)
					if configs.reportMetrics {
						updateHTTPMetrics(for: request, status: response.status, duration: duration, successful: false)
					}
					#endif
					throw error
				}
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
