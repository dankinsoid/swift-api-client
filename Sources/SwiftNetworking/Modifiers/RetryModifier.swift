import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

// public extension NetworkClient {
//
//	func retry(limit: Int?) -> NetworkClient {
//		configs {
//			$0.httpClient = RetryClient(
//				base: $0.httpClient,
//				retryLimit: limit
//			)
//		}
//	}
// }
//
// private struct RetryClient: HTTPClient {
//
//	let base: HTTPClient
//	let retryLimit: Int?
//
//	func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
//		var count = 0
//		func needRetry() -> Bool {
//			if let retryLimit {
//				return count <= retryLimit
//			}
//			return true
//		}
//
//		func retry() async throws -> (Data, HTTPURLResponse) {
//			count += 1
//			return try await self.data(for: request)
//		}
//
//		let response: HTTPURLResponse
//		let data: Data
//		do {
//			(data, response) = try await retry()
//		} catch {
//			if needRetry() {
//				return try await retry()
//			}
//			throw error
//		}
//		if !response.isStatusCodeValid, needRetry() {
//			return try await retry()
//		}
//		return (data, response)
//	}
// }
