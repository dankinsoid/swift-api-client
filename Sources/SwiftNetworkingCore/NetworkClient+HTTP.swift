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
		NetworkClientCaller { uuid, request, configs, serialize in
			{
				var request = request
				if request.httpMethod == nil {
					request.httpMethod = HTTPMethod.get.rawValue
				}
				if request.httpBodyStream != nil {
					configs.logger.error("HTTPBodyStream is not supported with a http caller. Use httpUpload instead.")
				}
                let start = Date()
				let (data, response) = try await configs.httpClient.data(request, configs)
                if !configs.loggingComponents.isEmpty {
                    let message = configs.loggingComponents.responseMessage(
                        for: response,
                        uuid: uuid,
                        data: data,
                        duration: Date().timeIntervalSince(start)
                    )
                    configs.logger.info("\(message)")
                }
				return try serialize(data) {
					try configs.httpResponseValidator.validate(response, data, configs)
				}
			}
		} mockResult: { value in
			{ value }
		}
	}
}
