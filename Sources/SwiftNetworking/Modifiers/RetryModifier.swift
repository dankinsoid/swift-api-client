import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NetworkClient {

	/// Retries the request if it fails.
	func retry(limit: Int?) -> NetworkClient {
		httpClientMiddleware(RetryMiddleware(limit: limit))
	}
}

private struct RetryMiddleware: HTTPClientMiddleware {

	let limit: Int?

	func execute<T>(
		request: URLRequest,
		configs: NetworkClient.Configs,
		next: (URLRequest, NetworkClient.Configs) async throws -> (T, HTTPURLResponse)
	) async throws -> (T, HTTPURLResponse) {
		var count = 0
		func needRetry() -> Bool {
			if let limit {
				return count <= limit
			}
			return true
		}

		func retry() async throws -> (T, HTTPURLResponse) {
			count += 1
			return try await next(request, configs)
		}

		let response: HTTPURLResponse
		let data: T
		do {
			(data, response) = try await retry()
		} catch {
			if needRetry() {
				return try await retry()
			}
			throw error
		}
		if !response.httpStatusCode.isSuccess, needRetry() {
			return try await retry()
		}
		return (data, response)
	}
}
