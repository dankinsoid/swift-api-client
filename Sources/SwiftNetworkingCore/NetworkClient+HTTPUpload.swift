import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPUploadClient {

	/// A closure that asynchronously retrieves data and an HTTP response for a given URLRequest and network configurations.
	public var upload: (URLRequest, UploadTask, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse)

	/// Initializes a new `HTTPUploadClient` with a custom data retrieval closure.
	/// - Parameter data: A closure that takes a `URLRequest` and `NetworkClient.Configs`, then asynchronously returns `Data` and an `HTTPURLResponse`.
	public init(
		_ upload: @escaping (URLRequest, UploadTask, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse))
	{
		self.upload = upload
	}
}

public enum UploadTask: Equatable {

	case file(URL)
	case data(Data)
	case stream
}

public extension NetworkClient {

	/// Sets a custom HTTP upload client for the network client.
	/// - Parameter client: The `HTTPUploadClient` to be used for network requests.
	/// - Returns: An instance of `NetworkClient` configured with the specified HTTP client.
	func httpUploadClient(_ client: HTTPUploadClient) -> NetworkClient {
		configs(\.httpUploadClient, client)
	}
}

public extension NetworkClient.Configs {

	/// The HTTP client used for upload network operations.
	/// Gets the currently set `HTTPUploadClient`, or the default `URLsession`-based client if not set.
	/// Sets a new `HTTPUploadClient`.
	var httpUploadClient: HTTPUploadClient {
		get { self[\.httpUploadClient] ?? .urlSession }
		set { self[\.httpUploadClient] = newValue }
	}
}

public extension NetworkClientCaller where Result == AsyncValue<Value>, Response == Data {

	static func httpUpload(_ task: UploadTask = .stream) -> NetworkClientCaller {
		.http { request, configs in
			var request = request
			if request.httpMethod == nil {
				request.httpMethod = HTTPMethod.post.rawValue
			}
			if task == .stream, request.httpBodyStream == nil {
				if let body = request.httpBody {
					request.httpBody = nil
					request.httpBodyStream = InputStream(data: body)
				} else {
					configs.logger.warning("There is no httpBodyStream in the request \(request).")
				}
			}
			return try await configs.httpUploadClient.upload(request, task, configs)
		}
	}
}
