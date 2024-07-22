import Foundation

public extension APIClient {

	#if canImport(Security)
	/// Adds a `TokenRefresherMiddleware` to the client.
	/// `TokenRefresherMiddleware` is used to refresh the token when it expires.
	/// - Parameters:
	/// - cacheService: The `SecureCacheService` to use for caching the token. Default to `.keychain`. Token must be stored with the key `.accessToken`.
	/// - expiredStatusCodes: The set of status codes that indicate an expired token. Default to `[401]`.
	/// - request: The closure to use for requesting a new token and refresh token first time. Set to `nil` if you want to request and cache tokens manually.
	/// - refresh: The closure to use for refreshing a new token with refresh token.
	/// - auth: The closure that creates an `AuthModifier` for the new token. Default to `.bearer(token:)`.
	///
	/// - Warning: Don't use this modifier with `.auth(_ modifier:)` as it will be override it.
	func tokenRefresher(
		cacheService: SecureCacheService = valueFor(live: .keychain, test: .mock),
		expiredStatusCodes: Set<HTTPResponse.Status> = [.unauthorized],
		request: ((APIClient, APIClient.Configs) async throws -> (accessToken: String, refreshToken: String?, expiryDate: Date?))? = nil,
		refresh: @escaping (_ refreshToken: String?, APIClient, APIClient.Configs) async throws -> (accessToken: String, refreshToken: String?, expiryDate: Date?),
		auth: @escaping (String) -> AuthModifier = AuthModifier.bearer
	) -> Self {
		httpClientMiddleware(
			TokenRefresherMiddleware(
				cacheService: cacheService,
				expiredStatusCodes: expiredStatusCodes,
				request: request.map { request in { try await request(self, $0) } },
				refresh: { try await refresh($0, self, $1) },
				auth: auth
			)
		)
	}
	#else
	/// Adds a `TokenRefresherMiddleware` to the client.
	/// `TokenRefresherMiddleware` is used to refresh the token when it expires.
	/// - Parameters:
	/// - cacheService: The `SecureCacheService` to use for caching the token. Default to `.keychain`. Token must be stored with the key `.accessToken`.
	/// - expiredStatusCodes: The set of status codes that indicate an expired token. Default to `[401]`.
	/// - request: The closure to use for requesting a new token and refresh token first time. Set to `nil` if you want to request and cache tokens manually.
	/// - refresh: The closure to use for refreshing a new token with refresh token.
	/// - auth: The closure that creates an `AuthModifier` for the new token. Default to `.bearer(token:)`.
	///
	/// - Warning: Don't use this modifier with `.auth(_ modifier:)` as it will be override it.
	func tokenRefresher(
		cacheService: SecureCacheService,
		expiredStatusCodes: Set<HTTPResponse.Status> = [.unauthorized],
		request: ((APIClient, APIClient.Configs) async throws -> (accessToken: String, refreshToken: String?, expiryDate: Date?))? = nil,
		refresh: @escaping (_ refreshToken: String?, APIClient, APIClient.Configs) async throws -> (accessToken: String, refreshToken: String?, expiryDate: Date?),
		auth: @escaping (String) -> AuthModifier = AuthModifier.bearer
	) -> Self {
		httpClientMiddleware(
			TokenRefresherMiddleware(
				cacheService: cacheService,
				expiredStatusCodes: expiredStatusCodes,
				request: request.map { request in { try await request(self, $0) } },
				refresh: { try await refresh($0, self, $1) },
				auth: auth
			)
		)
	}
	#endif
}

public struct TokenRefresherMiddleware: HTTPClientMiddleware {

	private let tokenCacheService: SecureCacheService
	private let expiredStatusCodes: Set<HTTPResponse.Status>
	private let auth: (String) -> AuthModifier
	private let requestToken: ((APIClient.Configs) async throws -> (String, String?, Date?))?
	private let refresh: (String?, APIClient.Configs) async throws -> (String, String?, Date?)

	public init(
		cacheService: SecureCacheService,
		expiredStatusCodes: Set<HTTPResponse.Status> = [.unauthorized],
		request: ((APIClient.Configs) async throws -> (String, String?, Date?))?,
		refresh: @escaping (String?, APIClient.Configs) async throws -> (String, String?, Date?),
		auth: @escaping (String) -> AuthModifier
	) {
		tokenCacheService = cacheService
		self.refresh = refresh
		requestToken = request
		self.auth = auth
		self.expiredStatusCodes = expiredStatusCodes
	}

	public func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		guard configs.isAuthEnabled else {
			return try await next(request, configs)
		}
		var accessToken: String
		var currentExpiryDate: Date?
		var refreshToken: String?
		if let cachedToken = try await tokenCacheService.load(for: .accessToken) {
			accessToken = cachedToken
			currentExpiryDate = try await tokenCacheService.load(for: .expiryDate)
			refreshToken = try await tokenCacheService.load(for: .refreshToken)
		} else if let requestToken, let url = request.url {
			(accessToken, refreshToken, currentExpiryDate) = try await withThrowingSynchronizedAccess(id: url.host) {
				try await requestToken(configs)
			}
		} else {
			throw TokenNotFound()
		}

		if
			let currentExpiryDate,
			currentExpiryDate < Date()
		{
			(accessToken, refreshToken, _) = try await refreshTokenAndCache(configs, accessToken: accessToken, refreshToken: refreshToken)
		} else {
			if let values = await waitForSynchronizedAccess(id: accessToken, of: (String, String?, Date?).self) {
				(accessToken, refreshToken, currentExpiryDate) = values
			}
		}
		var authorizedRequest = request
		try auth(accessToken).modifier(&authorizedRequest, configs)
		let result = try await next(authorizedRequest, configs)
		if expiredStatusCodes.contains(result.1.status) {
			(accessToken, refreshToken, _) = try await refreshTokenAndCache(configs, accessToken: accessToken, refreshToken: refreshToken)
			authorizedRequest = request
			try auth(accessToken).modifier(&authorizedRequest, configs)
			return try await next(authorizedRequest, configs)
		}
		return result
	}

	private func refreshTokenAndCache(
		_ configs: APIClient.Configs,
		accessToken: String,
		refreshToken: String?
	) async throws -> (String, String?, Date?) {
		try await withThrowingSynchronizedAccess(id: accessToken) { [self] in
			let (token, refreshToken, expiryDate) = try await refresh(refreshToken, configs)
			try await tokenCacheService.save(token, for: .accessToken)
			if let refreshToken {
				try await tokenCacheService.save(refreshToken, for: .refreshToken)
			}
			if let expiryDate {
				try await tokenCacheService.save(expiryDate, for: .expiryDate)
			}
			return (token, refreshToken, expiryDate)
		}
	}
}

public struct TokenNotFound: Error {
    
    public init() {}
}
