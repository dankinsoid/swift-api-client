import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A struct representing an HTTP client capable of performing network requests.
public struct HTTPClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URLRequest and network configurations.
	public var data: (HTTPRequest, RequestBody?, APIClient.Configs) async throws -> (Data, HTTPResponse)

	/// Initializes a new `HTTPClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a `URLRequest` and `APIClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(_ data: @escaping (HTTPRequest, RequestBody?, APIClient.Configs) async throws -> (Data, HTTPResponse)) {
		self.data = data
	}
}

public enum RequestBody: Hashable {

	case file(URL)
	case data(Data)
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
			var request = request
			if request.httpBodyStream != nil {
				configs.logger.warning(".httpBodyStream is not supported, use .body(file:) modifier.")
			}
			let isUpload = request.httpBody != nil || configs.file != nil
			if request.httpMethod == nil {
				request.method = isUpload ? .post : .get
			}
			if isUpload, request.method == .get {
				configs.logger.warning("It is not allowed to add a body in GET request.")
			}

			if request.httpBody != nil, configs.file != nil {
				configs.logger.warning("Both body data and body file are set for the request \(request.url?.absoluteString ?? "").")
			}

			let body: RequestBody?
			if let httpBody = request.httpBody {
				body = .data(httpBody)
			} else if let file = configs.file?(configs) {
				body = .file(file)
			} else {
				body = nil
			}
			return try await configs.httpClient.data(request, body, configs)
		}
	}
}

extension APIClientCaller where Result == AsyncThrowingValue<Value>, Response == Data {

	static func http(
		task: @escaping @Sendable (HTTPRequest, Data?, APIClient.Configs) async throws -> (Data, HTTPResponse)
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
		task: @escaping @Sendable (HTTPRequest, Data?, APIClient.Configs) async throws -> (Response, HTTPResponse),
		validate: @escaping (Response, HTTPResponse, APIClient.Configs) throws -> Void,
		data: @escaping (Response) -> Data?
	) -> APIClientCaller {
		APIClientCaller { uuid, request, body, configs, serialize in
			{
				let value: Response
				let response: HTTPResponse
				let start = Date()
				do {
                    (value, response) = try await configs.httpClientMiddleware.execute(request: request, body: body, configs: configs, next: task)
				} catch {
					let duration = Date().timeIntervalSince(start)
					if !configs.loggingComponents.isEmpty {
						let message = configs.loggingComponents.errorMessage(
							uuid: uuid,
							error: error,
							duration: duration
						)
						configs.logger.error("\(message)")
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
						configs.logger.error("\(message)")
					}
					throw error
				}
			}
		} mockResult: { value in
			{ value }
		}
	}
}
