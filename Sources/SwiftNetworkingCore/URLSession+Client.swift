import Foundation
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension HTTPClient {

	/// Creates an `HTTPClient` that uses a specified `URLSession` for network requests.
	/// - Parameter session: The `URLSession` to use for network requests.
	/// - Returns: An `HTTPClient` that uses the given `URLSession` to fetch data.
	static func urlSession(_ session: URLSession) -> Self {
		HTTPClient { request, _ in
			#if os(Linux)
			return try await asyncMethod { completion in
				session.dataTask(with: request, completionHandler: completion)
			}
			#else
			if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
				let (data, response) = try await session.data(for: request)
				guard let httpResponse = response.http else {
					throw Errors.responseTypeIsNotHTTP
				}
				return (data, httpResponse)
			} else {
				return try await asyncMethod { completion in
					session.dataTask(with: request, completionHandler: completion)
				}
			}
			#endif
		}
	}

	/// A static property to get an `HTTPClient` that uses the shared `URLSession`.
	static var urlSession: Self {
		urlSession(.shared)
	}
}

// public extension HTTPUploadClient {

// 	static func urlSession(_ session: URLSession) -> Self {
// 		HTTPUploadClient { request, uploadTask, _ in
// 		  try await asyncMethod { completion in
// 				session.uploadTask(with: request, task: uploadTask, completionHandler: completion)
// 			}
// 		}
// 	}

// 	static var urlSession: Self {
// 		urlSession(.shared)
// 	}
// }

// private extension URLSession {

// 	func uploadTask(with request: URLRequest, task: UploadTask, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionUploadTask {
// 		switch task {
// 			case let .data(data):
// 				return uploadTask(with: request, from: data, completionHandler: completionHandler)
// 			case let .file(url):
// 				return uploadTask(with: request, fromFile: url, completionHandler: completionHandler)
// 			case .stream:
// 			return uploadTask(withStreamedRequest: request)
// 		}
// 	}
// }

private func asyncMethod<T, S: URLSessionTask>(
	_ method: @escaping (
		@escaping @Sendable (T?, URLResponse?, Error?) -> Void
	) -> S
) async throws -> (T, HTTPURLResponse) {
	try await completionToThrowsAsync { continuation, handler in
		let task = method { t, response, error in
			if let t, let response = response?.http {
				continuation.resume(returning: (t, response))
			} else {
				if (error as? NSError)?.code == NSURLErrorCancelled {
					continuation.resume(throwing: CancellationError())
				} else {
					continuation.resume(throwing: error ?? Errors.unknown)
				}
			}
		}
		handler.onCancel {
			task.cancel()
		}
		task.resume()
	}
}

private final class URLSessionDelegateProxy: NSObject, URLSessionDelegate {}
