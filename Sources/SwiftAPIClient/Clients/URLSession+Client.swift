import Foundation
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension HTTPClient {

	/// Creates an `HTTPClient` that uses a specified `URLSession` for network requests.
	/// - Returns: An `HTTPClient` that uses the given `URLSession` to fetch data.
	static var urlSession: Self {
		HTTPClient { request, configs in
            guard
                let url = request.url,
                let httpRequest = request.request,
                var urlRequest = URLRequest(httpRequest: httpRequest)
            else {
				throw Errors.custom("Invalid request")
			}
            urlRequest.url = url
			#if os(Linux)
			guard let urlRequest = URLRequest(request: urlRequest, body: body, configs: configs) else {
				throw Errors.custom("Invalid request")
			}
			return try await asyncMethod { completion in
				configs.urlSession.uploadTask(with: urlRequest, body: body, completionHandler: completion)
			}
			#else
			if #available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *) {
				let (data, response) = try await customErrors {
                    try await configs.urlSession.data(for: urlRequest, body: request.body)
				}
				return (data, response.http)
			} else {
				return try await asyncMethod { completion in
                    configs.urlSession.uploadTask(with: urlRequest, body: request.body, completionHandler: completion)
				}
			}
			#endif
		}
	}
}

public extension HTTPDownloadClient {

	static var urlSession: Self {
		HTTPDownloadClient { request, configs in
			guard let urlRequest = URLRequest(request: request, configs: configs) else {
				throw Errors.custom("Invalid request")
			}
			return try await asyncMethod { completion in
				configs.urlSession.downloadTask(with: urlRequest, completionHandler: completion)
			}
		}
	}
}

private extension URLSession {

	@available(macOS 12.0, iOS 15.0, watchOS 8.0, tvOS 15.0, *)
	func data(for request: URLRequest, body: RequestBody?) async throws -> (Data, URLResponse) {
		switch body {
		case let .file(url):
			return try await upload(for: request, fromFile: url)
		case let .data(body):
			return try await upload(for: request, from: body)
		case nil:
			return try await data(for: request)
		}
	}

	func uploadTask(with request: URLRequest, body: RequestBody?, completionHandler: @escaping @Sendable (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
		switch body {
		case let .data(data):
			return uploadTask(with: request, from: data, completionHandler: completionHandler)
		case let .file(url):
			return uploadTask(with: request, fromFile: url, completionHandler: completionHandler)
		case nil:
			return dataTask(with: request, completionHandler: completionHandler)
		}
	}
}

private func asyncMethod<T, S: URLSessionTask>(
	_ method: @escaping (
		@escaping @Sendable (T?, URLResponse?, Error?) -> Void
	) -> S
) async throws -> (T, HTTPResponse) {
	try await customErrors {
		try await completionToThrowsAsync { continuation, handler in
			let task = method { t, response, error in
				if let t, let response {
					continuation.resume(returning: (t, response.http))
				} else {
					continuation.resume(throwing: error ?? Errors.unknown)
				}
			}
			handler.onCancel {
				task.cancel()
			}
			task.resume()
		}
	}
}

private func customErrors<T>(_ operation: () async throws -> T) async throws -> T {
	do {
		return try await operation()
	} catch let error as URLError {
		switch error.code {
		case .cancelled:
			throw CancellationError()
		case .timedOut:
			throw TimeoutError()
		default:
			throw error
		}
	} catch let error as NSError {
		if error.code == NSURLErrorCancelled {
			throw CancellationError()
		}
		throw error
	} catch {
		throw error
	}
}

private final class URLSessionDelegateProxy: NSObject, URLSessionDelegate {}
