import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient {

	/// Retries the request if it fails.
	func retry(limit: Int?) -> APIClient {
		httpClientMiddleware(RetryMiddleware(limit: limit))
	}
}

private struct RetryMiddleware: HTTPClientMiddleware {

	let limit: Int?

	func execute<T>(
		request: HTTPRequest,
        body: Data?,
		configs: APIClient.Configs,
		next: (HTTPRequest, Data?, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		var count = 0
		func needRetry() -> Bool {
			if let limit {
				return count <= limit
			}
			return true
		}

		func retry() async throws -> (T, HTTPResponse) {
			count += 1
            return try await next(request, body, configs)
		}

		let response: HTTPResponse
		let data: T
		do {
			(data, response) = try await retry()
		} catch {
			if needRetry() {
				return try await retry()
			}
			throw error
		}
        if response.status.kind != .successful, needRetry() {
			return try await retry()
		}
		return (data, response)
	}
}
