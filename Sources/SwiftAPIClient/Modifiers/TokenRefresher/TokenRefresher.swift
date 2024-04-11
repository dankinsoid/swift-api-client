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
        request: @escaping (SecureCacheService) async -> String? = { await $0.load(for: .accessToken) },
		refresh: @escaping (_ refreshToken: String?, APIClient, APIClient.Configs) async throws -> (accessToken: String, refreshToken: String?, expiryDate: Date?),
		auth: @escaping (String) -> AuthModifier = AuthModifier.bearer
	) -> Self {
		httpClientMiddleware(
			TokenRefresherMiddleware(
				cacheService: cacheService,
				expiredStatusCodes: expiredStatusCodes,
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
        refresh: @escaping (_ refreshToken: String?, APIClient, APIClient.Configs) async throws -> (accessToken: String, refreshToken: String?, expiryDate: Date?),
        auth: @escaping (String) -> AuthModifier = AuthModifier.bearer
    ) -> Self {
        httpClientMiddleware(
            TokenRefresherMiddleware(
                cacheService: cacheService,
                expiredStatusCodes: expiredStatusCodes,
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
	private let refresh: (String?, APIClient.Configs) async throws -> (String, String?, Date?)

	public init(
		cacheService: SecureCacheService,
		expiredStatusCodes: Set<HTTPResponse.Status> = [.unauthorized],
		refresh: @escaping (String?, APIClient.Configs) async throws -> (String, String?, Date?),
		auth: @escaping (String) -> AuthModifier
	) {
		tokenCacheService = cacheService
		self.refresh = refresh
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
        guard var accessToken = await tokenCacheService.load(for: .accessToken) else {
            throw Errors.custom("Token not found.")
        }
        var refreshToken = await tokenCacheService.load(for: .refreshToken)

        if
            let expiryDateString = await tokenCacheService.load(for: .expiryDate),
            let currentExpiryDate = dateFormatter.date(from: expiryDateString),
            currentExpiryDate > Date()
        {
            (accessToken, refreshToken, _) = try await refreshTokenAndCache(configs, accessToken: accessToken, refreshToken: refreshToken)
        } else {
            let token = await waitForSynchronizedAccess(id: accessToken, of: (String, String?, Date?).self)?.0
            accessToken = token ?? accessToken
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
                try await tokenCacheService.save(dateFormatter.string(from: expiryDate), for: .expiryDate)
            }
            return (token, refreshToken, expiryDate)
        }
	}
}

private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
	return formatter
}()
