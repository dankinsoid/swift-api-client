import Foundation
import SwiftNetworkingCore

protocol TokenCacheService {

	func saveToken(_ token: String)
	func getToken() -> String?
	func clearToken()
}

extension NetworkClient {

	func bearerAuth(_ service: TokenCacheService) -> NetworkClient {
		// It's not required to create a .tokenCacheService config in this case, but it allows to override the token cache service and use it in other services, for instance, in a token refresher.
		configs(\.tokenCacheService, service)
			.auth(
				AuthModifier { request, configs in
					guard let token = configs.tokenCacheService.getToken() else {
						throw NoToken()
					}
					request.setHeader(.authorization(bearerToken: token))
				}
			)
	}
}

extension NetworkClient.Configs {

	var tokenCacheService: TokenCacheService {
		get {
			self[\.tokenCacheService] ?? valueFor(
				live: UserDefaultsTokenCacheService() as TokenCacheService,
				test: MockTokenCacheService()
			)
		}
		set {
			self[\.tokenCacheService] = newValue
		}
	}
}

struct UserDefaultsTokenCacheService: TokenCacheService {

	/// Key used to store the token in UserDefaults
	private let tokenKey = "APIToken"

	/// UserDefaults instance for data storage
	private let defaults: UserDefaults

	/// Initializer allowing injection of UserDefaults instance for flexibility and testability
	init(defaults: UserDefaults = .standard) {
		self.defaults = defaults
	}

	/// Function to save the API token
	func saveToken(_ token: String) {
		defaults.set(token, forKey: tokenKey)
	}

	/// Function to retrieve the API token
	func getToken() -> String? {
		defaults.string(forKey: tokenKey)
	}

	/// Function to clear the API token
	func clearToken() {
		defaults.removeObject(forKey: tokenKey)
	}
}

final class MockTokenCacheService: TokenCacheService {

	private var token: String?

	static let shared = MockTokenCacheService()

	func saveToken(_ token: String) {
		self.token = token
	}

	func getToken() -> String? {
		token
	}

	func clearToken() {
		token = nil
	}
}

private struct NoToken: Error {}
