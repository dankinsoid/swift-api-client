import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPDownloadClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URLRequest and network configurations.
	public var download: (URLRequest, NetworkClient.Configs) async throws -> (URL, HTTPURLResponse)

	/// Initializes a new `HTTPUploadClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a `URLRequest` and `NetworkClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(
		_ download: @escaping (URLRequest, NetworkClient.Configs) async throws -> (URL, HTTPURLResponse))
	{
		self.download = download
	}
}

public extension NetworkClient {

	/// Sets a custom  HTTP download client for the network client.
	/// - Parameter client: The `HTTPDownloadClient` to be used for network requests.
	/// - Returns: An instance of `NetworkClient` configured with the specified HTTP client.
	func httpDownloadClient(_ client: HTTPDownloadClient) -> NetworkClient {
		configs(\.httpDownloadClient, client)
	}
}

public extension NetworkClient.Configs {

	/// The HTTP client used for network download operations.
	/// Gets the currently set `HTTPDownloadClient`, or the default `URLsession`-based client if not set.
	/// Sets a new `HTTPDownloadClient`.
	var httpDownloadClient: HTTPDownloadClient {
		get { self[\.httpDownloadClient] ?? .urlSession }
		set { self[\.httpDownloadClient] = newValue }
	}
}

public extension NetworkClientCaller where Result == AsyncValue<Value>, Response == URL {

	static var httpDownload: NetworkClientCaller {
		.http { request, configs in
			var request = request
			if request.httpMethod == nil {
				request.httpMethod = HTTPMethod.get.rawValue
			}
			return try await configs.httpDownloadClient.download(request, configs)
		} validate: { _, _, _ in
		} data: { _ in
			nil
		}
	}
}
