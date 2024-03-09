import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A struct representing an HTTP client capable of performing network requests.
public struct HTTPClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URLRequest and network configurations.
	public var data: (URLRequest, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse)

	/// Initializes a new `HTTPClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a `URLRequest` and `NetworkClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(_ data: @escaping (URLRequest, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse)) {
		self.data = data
	}
}

public extension NetworkClient {

	/// Sets a custom HTTP client for the network client.
	/// - Parameter client: The `HTTPClient` to be used for network requests.
	/// - Returns: An instance of `NetworkClient` configured with the specified HTTP client.
	func httpClient(_ client: HTTPClient) -> NetworkClient {
		configs(\.httpClient, client)
	}
}

public extension NetworkClient.Configs {

	/// The HTTP client used for network operations.
	/// Gets the currently set `HTTPClient`, or the default `URLsession`-based client if not set.
	/// Sets a new `HTTPClient`.
	var httpClient: HTTPClient {
		get { self[\.httpClient] ?? .urlSession }
		set { self[\.httpClient] = newValue }
	}
}

public extension NetworkClientCaller where Result == AsyncValue<Value>, Response == Data {

	static var http: NetworkClientCaller {
		.http { request, configs in
			var request = request
			if request.httpMethod == nil {
				request.httpMethod = HTTPMethod.get.rawValue
			}
			if request.httpBodyStream != nil {
				configs.logger.warning("HTTPBodyStream is not supported with a http caller. Use httpUpload instead.")
			}
			return try await configs.httpClient.data(request, configs)
		}
	}
}

extension NetworkClientCaller where Result == AsyncValue<Value>, Response == Data {

	static func http(
		task: @escaping @Sendable (URLRequest, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse)
	) -> NetworkClientCaller {
		.http(task: task) {
			try $2.httpResponseValidator.validate($1, $0, $2)
		} data: {
			$0
		}
	}
}

extension NetworkClientCaller where Result == AsyncValue<Value> {

	static func http(
		task: @escaping @Sendable (URLRequest, NetworkClient.Configs) async throws -> (Response, HTTPURLResponse),
		validate: @escaping (Response, HTTPURLResponse, NetworkClient.Configs) throws -> Void,
		data: @escaping (Response) -> Data?
	) -> NetworkClientCaller {
		NetworkClientCaller { uuid, request, configs, serialize in
			{
				let value: Response
				let response: HTTPURLResponse
				let start = Date()
				do {
					(value, response) = try await task(request, configs)
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
