import Foundation

public extension APIClient {

	/// Adds a `TokenRefresherMiddleware` to the client.
	/// `TokenRefresherMiddleware` is used to refresh the token when it expires.
	/// - Parameters:
	/// - cacheService: The `SecureCacheService` to use for caching the token. Default to `.keychain`.
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
}

public struct TokenRefresherMiddleware: HTTPClientMiddleware {

	private let tokenCacheService: SecureCacheService
	private let expiredStatusCodes: Set<HTTPResponse.Status>
	private let auth: (String) -> AuthModifier
	private let request: ((APIClient.Configs) async throws -> (String, String?, Date?))?
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
		self.request = request
		self.auth = auth
		self.expiredStatusCodes = expiredStatusCodes
	}

	public func execute<T>(
		request: HTTPRequest,
		body: RequestBody?,
		configs: APIClient.Configs,
		next: (HTTPRequest, RequestBody?, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		guard configs.isAuthEnabled else {
			return try await next(request, body, configs)
		}
		var accessToken: String
		var refreshToken = tokenCacheService[.refreshToken]
		if let currentToken = tokenCacheService[.accessToken] {
			if
				let expiryDateString = tokenCacheService[.expiryDate],
				let currentExpiryDate = dateFormatter.date(from: expiryDateString),
				currentExpiryDate > Date()
			{
				(accessToken, refreshToken, _) = try await refreshTokenAndCache(configs, refreshToken: refreshToken)
			} else {
				accessToken = currentToken
			}
		} else {
			(accessToken, refreshToken, _) = try await requestTokenAndCache(configs)
		}
		var authorizedRequest = request
		try auth(accessToken).modifier(&authorizedRequest, configs)
		let result = try await next(authorizedRequest, body, configs)
		if expiredStatusCodes.contains(result.1.status) {
			(accessToken, refreshToken, _) = try await refreshTokenAndCache(configs, refreshToken: refreshToken)
			authorizedRequest = request
			try auth(accessToken).modifier(&authorizedRequest, configs)
			return try await next(authorizedRequest, body, configs)
		}
		return result
	}

	private func requestTokenAndCache(
		_ configs: APIClient.Configs
	) async throws -> (String, String?, Date?) {
		guard let request else {
			throw Errors.custom("No cached token found.")
		}
		let (token, refreshToken, expiryDate) = try await request(configs)
		tokenCacheService[.accessToken] = token
		if let refreshToken {
			tokenCacheService[.refreshToken] = refreshToken
		}
		if let expiryDate {
			tokenCacheService[.expiryDate] = dateFormatter.string(from: expiryDate)
		}
		return (token, refreshToken, expiryDate)
	}

	private func refreshTokenAndCache(
		_ configs: APIClient.Configs,
		refreshToken: String?
	) async throws -> (String, String?, Date?) {
		let (token, refreshToken, expiryDate) = try await refresh(refreshToken, configs)
		tokenCacheService[.accessToken] = token
		if let refreshToken {
			tokenCacheService[.refreshToken] = refreshToken
		}
		if let expiryDate {
			tokenCacheService[.expiryDate] = dateFormatter.string(from: expiryDate)
		}
		return (token, refreshToken, expiryDate)
	}
}

private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
	return formatter
}()
