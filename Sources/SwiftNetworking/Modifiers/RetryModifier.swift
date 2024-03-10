import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

 public extension NetworkClient {

    /// Retries the request if it fails.
	func retry(limit: Int?) -> NetworkClient {
		configs {
            let client = $0.httpClient
            $0.httpClient = HTTPClient { request, configs in
                var count = 0
                func needRetry() -> Bool {
                    if let limit {
                        return count <= limit
                    }
                    return true
                }
                
                func retry() async throws -> (Data, HTTPURLResponse) {
                    count += 1
                    return try await client.data(request, configs)
                }
                
                let response: HTTPURLResponse
                let data: Data
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
	}
 }
