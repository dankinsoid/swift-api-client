import Foundation
import HTTPTypes
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPDownloadClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URL request and network configurations.
	public var download: (HTTPRequestComponents, APIClient.Configs) async throws -> (URL, HTTPResponse)

	/// Initializes a new `HTTPDownloadClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a URL request and `APIClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(
		_ download: @escaping (HTTPRequestComponents, APIClient.Configs) async throws -> (URL, HTTPResponse))
	{
		self.download = download
	}
}

public extension APIClient {

	/// Sets a custom  HTTP download client for the network client.
	/// - Parameter client: The `HTTPDownloadClient` to be used for network requests.
	/// - Returns: An instance of `APIClient` configured with the specified HTTP client.
	func httpDownloadClient(_ client: HTTPDownloadClient) -> APIClient {
		configs(\.httpDownloadClient, client)
	}

	/// Observe the download progress of the request.
	func trackDownload(_ action: @escaping (_ progress: Double) -> Void) -> Self {
		trackDownload { totalBytesWritten, totalBytesExpectedToWrite in
			guard totalBytesExpectedToWrite > 0 else {
				action(1)
				return
			}
			action(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite))
		}
	}

	/// Observe the download progress of the request.
	func trackDownload(_ action: @escaping (_ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> Void) -> Self {
		configs {
			let current = $0.downloadTracker
			$0.downloadTracker = { totalBytesWritten, totalBytesExpectedToWrite in
				current(totalBytesWritten, totalBytesExpectedToWrite)
				action(totalBytesWritten, totalBytesExpectedToWrite)
			}
		}
	}
}

public extension APIClient.Configs {

	/// The HTTP client used for network download operations.
	/// Gets the currently set `HTTPDownloadClient`, or the default `URLsession`-based client if not set.
	/// Sets a new `HTTPDownloadClient`.
	var httpDownloadClient: HTTPDownloadClient {
		get { self[\.httpDownloadClient] ?? .urlSession }
		set { self[\.httpDownloadClient] = newValue }
	}

	/// The closure that provides the data for the request.
	var downloadTracker: (_ totalBytesWritten: Int64, _ totalBytesExpectedToWrite: Int64) -> Void {
		get { self[\.downloadTracker] ?? { _, _ in } }
		set { self[\.downloadTracker] = newValue }
	}
}

public extension APIClientCaller where Result == AsyncThrowingValue<Value>, Response == URL {

	static var httpDownload: APIClientCaller {
		APIClientCaller<URL, Value, AsyncThrowingValue<(Value, HTTPResponse)>>
			.httpDownloadResponse
			.dropHTTPResponse
	}
}

public extension APIClientCaller where Result == AsyncThrowingValue<(Value, HTTPResponse)>, Response == URL {

	static var httpDownloadResponse: APIClientCaller {
		HTTPClientCaller<URL, Value>.http { request, configs in
			try await configs.httpDownloadClient.download(request, configs)
		} validate: { _, _, _ in
		} data: { _ in
			nil
		}
		.mapResponse(\.0)
	}
}
