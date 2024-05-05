import Foundation
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
		.http { request, configs in
			let isUpload = request.body != nil
			if isUpload, request.method == .get {
				configs.logger.warning("It is not allowed to add a body in GET request.")
			}
			return try await configs.httpClient.data(request, configs)
		}
	}
}

extension APIClientCaller where Result == AsyncThrowingValue<Value>, Response == Data {

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

extension APIClientCaller where Result == AsyncThrowingValue<Value> {

	static func http(
		task: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (Response, HTTPResponse),
		validate: @escaping (Response, HTTPResponse, APIClient.Configs) throws -> Void,
		data: @escaping (Response) -> Data?
	) -> APIClientCaller {
		APIClientCaller { uuid, request, configs, serialize in
			{
				let value: Response
				let response: HTTPResponse
				let start = Date()
				do {
					(value, response) = try await configs.httpClientMiddleware.execute(request: request, configs: configs, next: task)
				} catch {
					let duration = Date().timeIntervalSince(start)
					if !configs.loggingComponents.isEmpty {
						let message = configs.loggingComponents.errorMessage(
							uuid: uuid,
							error: error,
							duration: duration
						)
						configs.logger.log(level: configs.logLevel, "\(message)")
					}
					if configs.reportMetrics {
						updateHTTPMetrics(for: request, status: nil, duration: duration, successful: false)
					}
					throw error
				}
				let duration = Date().timeIntervalSince(start)
				let data = data(value)
				do {
					let result = try serialize(value) {
						try validate(value, response, configs)
					}
					if !configs.loggingComponents.isEmpty {
						let message = configs.loggingComponents.responseMessage(
							for: response,
							uuid: uuid,
							data: data,
							duration: duration
						)
						configs.logger.log(level: configs.logLevel, "\(message)")
					}
					if configs.reportMetrics {
						updateHTTPMetrics(for: request, status: response.status, duration: duration, successful: true)
					}
					return result
				} catch {
					if !configs.loggingComponents.isEmpty {
						let message = configs.loggingComponents.responseMessage(
							for: response,
							uuid: uuid,
							data: data,
							duration: duration,
							error: error
						)
						configs.logger.log(level: configs.logLevel, "\(message)")
					}
					if configs.reportMetrics {
						updateHTTPMetrics(for: request, status: response.status, duration: duration, successful: false)
					}
					throw error
				}
			}
		} mockResult: { value in
			{ value }
		}
	}
}
