import Foundation
import SwiftNetworking

protocol TokenRefresher {

	func refreshTokenIfNeeded(
		operation: () async throws -> (Data, HTTPURLResponse)
	) async throws -> (Data, HTTPURLResponse)
}

extension NetworkClient {

	func tokenRefresher(_ refresher: @escaping (NetworkClient.Configs) -> TokenRefresher) -> NetworkClient {
		configs { configs in
			let base = configs.httpClient
			configs.httpClient = HTTPClient { request, configs in
				try await refresher(configs).refreshTokenIfNeeded {
					try await base.data(request, configs)
				}
			}
		}
	}
}

struct APITokenRefresher: TokenRefresher {

	let tokenService: TokenCacheService

	init(_ configs: NetworkClient.Configs) {
		tokenService = configs.tokenCacheService
	}

	private let tokenRefreshStatusCode = 401 // Status code indicating the token needs to be refreshed

	/// Checks if the token needs to be refreshed based on the status code
	func refreshTokenIfNeeded(
		operation: () async throws -> (Data, HTTPURLResponse)
	) async throws -> (Data, HTTPURLResponse) {
		let result = try await operation()
		if result.1.statusCode == tokenRefreshStatusCode {
			try await refreshToken()
			return try await operation()
		}
		return result
	}

	/// Function to refresh the API token
	private func refreshToken() async throws {
		// Implement token refresh logic here.
		// tokenService.saveToken("")
	}
}

struct MockTokenRefresher: TokenRefresher {

	func refreshTokenIfNeeded(
		operation: () async throws -> (Data, HTTPURLResponse)
	) async throws -> (Data, HTTPURLResponse) {
		try await operation()
	}
}
