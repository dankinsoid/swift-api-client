import Foundation

public extension HTTPClientMiddleware where Self == TokenRefresherMiddleware {

	static func tokenRefresher(
        cacheService: TokenCacheService = valueFor(live: .keychain, test: .mock),
		expiredStatusCodes: Set<HTTPStatusCode> = [.unauthorized],
		refreshToken: @escaping (NetworkClient.Configs) async throws -> String,
		auth: @escaping (String) -> AuthModifier
	) -> Self {
		TokenRefresherMiddleware(
			cacheService: cacheService,
			expiredStatusCodes: expiredStatusCodes,
			refreshToken: refreshToken,
			auth: auth
		)
	}
}

public struct TokenRefresherMiddleware: HTTPClientMiddleware {

	let tokenCacheService: TokenCacheService
	let expiredStatusCodes: Set<HTTPStatusCode>
	let auth: (String) -> AuthModifier
	let refreshToken: (NetworkClient.Configs) async throws -> String

	public init(
		cacheService: TokenCacheService,
		expiredStatusCodes: Set<HTTPStatusCode> = [.unauthorized],
		refreshToken: @escaping (NetworkClient.Configs) async throws -> String,
		auth: @escaping (String) -> AuthModifier
	) {
		tokenCacheService = cacheService
		self.refreshToken = refreshToken
		self.auth = auth
		self.expiredStatusCodes = expiredStatusCodes
	}

	public func execute<T>(
		request: URLRequest,
		configs: NetworkClient.Configs,
		next: (URLRequest, NetworkClient.Configs) async throws -> (T, HTTPURLResponse)
	) async throws -> (T, HTTPURLResponse) {
		var token: String
		let currentToken = tokenCacheService.getToken()
		if let currentToken {
			token = currentToken
		} else {
			token = try await refreshTokenAndCache(configs)
		}
		var authorizedRequest = request
		try auth(token).modifier(&authorizedRequest, configs)
		let result = try await next(authorizedRequest, configs)
		if expiredStatusCodes.contains(result.1.httpStatusCode) {
			token = try await refreshTokenAndCache(configs)
			authorizedRequest = request
			try auth(token).modifier(&authorizedRequest, configs)
			return try await next(authorizedRequest, configs)
		}
		return result
	}

	private func refreshTokenAndCache(_ configs: NetworkClient.Configs) async throws -> String {
		let token = try await refreshToken(configs)
		try? tokenCacheService.saveToken(token)
		return token
	}
}
