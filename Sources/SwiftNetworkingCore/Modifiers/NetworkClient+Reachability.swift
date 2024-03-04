#if canImport(Reachability)
import Foundation
import Reachability
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NetworkClient {

	/// Configures the network client to wait for a network connection before sending requests,
	/// with an optional retry mechanism for failed requests.
	/// - Parameters:
	///   - retryLimit: An optional integer specifying the maximum number of retries for a request.
	///                 If `nil`, it will keep retrying as long as the network is unreachable.
	///   - reachabilityService: A `ReachabilityService` instance to monitor network reachability.
	///                          Defaults to `.default`.
	/// - Returns: An instance of `NetworkClient` configured to handle network connectivity and retry logic.
	func waitForConnection(
		retryLimit: Int? = nil,
		reachabilityService: ReachabilityService = .default
	) -> NetworkClient {
		configs { configs in
			let client = configs.httpClient
			configs.httpClient = HTTPClient { request, configs in
				await reachabilityService.waitReachable()
				var count = 0
				func needRetry() -> Bool {
					guard !reachabilityService.isReachable else {
						return false
					}
					if let retryLimit {
						return count <= retryLimit
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
				if !response.isStatusCodeValid, needRetry() {
					return try await retry()
				}
				return (data, response)
			}
		}
	}
}
#endif
