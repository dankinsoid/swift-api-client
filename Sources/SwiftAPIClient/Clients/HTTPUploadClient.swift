import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPUploadClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URLRequest and network configurations.
	public var upload: (URLRequest, UploadTask, APIClient.Configs) async throws -> (Data, HTTPURLResponse)

	/// Initializes a new `HTTPUploadClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a `URLRequest` and `APIClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(
		_ upload: @escaping (URLRequest, UploadTask, APIClient.Configs) async throws -> (Data, HTTPURLResponse))
	{
		self.upload = upload
	}
}

public enum UploadTask: Hashable {

	case file(URL)
	case data(Data)
}

public extension APIClient.Configs {

	/// The closure that provides the file URL for the request.
	var file: ((APIClient.Configs) -> URL)? {
		get { self[\.file] }
		set { self[\.file] = newValue }
	}

	/// The closure that is called when the upload progress is updated.
	var uploadTracker: (_ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void {
		get { self[\.uploadTracker] ?? { _, _ in } }
		set { self[\.uploadTracker] = newValue }
	}
}

public extension APIClient {

	/// Sets a custom HTTP upload client for the network client.
	/// - Parameter client: The `HTTPUploadClient` to be used for network requests.
	/// - Returns: An instance of `APIClient` configured with the specified HTTP client.
	func httpUploadClient(_ client: HTTPUploadClient) -> APIClient {
		configs(\.httpUploadClient, client)
	}

	/// Observe the upload progress of the request.
	func trackUpload(_ action: @escaping (_ progress: Double) -> Void) -> Self {
		trackUpload { totalBytesSent, totalBytesExpectedToSend in
			guard totalBytesExpectedToSend > 0 else {
				action(1)
				return
			}
			action(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
		}
	}

	/// Observe the upload progress of the request.
	func trackUpload(_ action: @escaping (_ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void) -> Self {
		configs {
			let current = $0.uploadTracker
			$0.uploadTracker = { totalBytesSent, totalBytesExpectedToSend in
				current(totalBytesSent, totalBytesExpectedToSend)
				action(totalBytesSent, totalBytesExpectedToSend)
			}
		}
	}
}

public extension APIClient.Configs {

	/// The HTTP client used for upload network operations.
	/// Gets the currently set `HTTPUploadClient`, or the default `URLsession`-based client if not set.
	/// Sets a new `HTTPUploadClient`.
	var httpUploadClient: HTTPUploadClient {
		get { self[\.httpUploadClient] ?? .urlSession }
		set { self[\.httpUploadClient] = newValue }
	}
}
