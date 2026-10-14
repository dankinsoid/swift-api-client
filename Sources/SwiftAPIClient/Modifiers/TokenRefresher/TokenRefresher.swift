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
	///
	/// ### Example Usage:
	/// #### Initial Token Request
	/// ```swift
	/// let client = APIClient()
	///   .tokenRefresher { refreshToken, client, _ in
	///      let response: AuthResponse = try await client("refresh").post(RefreshRequest(token: refreshToken)))
	///      return (response.accessToken, response.refreshToken, response.expiryDate)
	///   }
	///
	/// func login(_ body: LoginBody) async throws {
	///   let response: AuthResponse = try await client("login").auth(enabled: false).post(body)
	///   // Tokens must be cached.
	///   try await SecureCacheService.keychain.saveTokens(
	///     CachedTokens(accessToken: response.accessToken, refreshToken: response.refreshToken, expiryDate: response.expiryDate)
	///   )
	/// }
	/// ```
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
	///
	/// ### Example Usage:
	/// #### Initial Token Request
	/// ```swift
	/// let client = APIClient()
	///   .tokenRefresher(cacheService: cacheService) { refreshToken, client, _ in
	///      let response: AuthResponse = try await client("refresh").post(RefreshRequest(token: refreshToken)))
	///      return (response.accessToken, response.refreshToken, response.expiryDate)
	///   }
	///
	/// func login(_ body: LoginBody) async throws {
	///   let response: AuthResponse = try await client("login").auth(enabled: false).post(body)
	///   // Tokens must be cached.
	///   try await cacheService.saveTokens(
	///     CachedTokens(accessToken: response.accessToken, refreshToken: response.refreshToken, expiryDate: response.expiryDate)
	///   )
	/// }
	/// ```
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

/// Authorizes requests with the cached access token and refreshes it on an expired status or expiry date.
///
/// Built for backends that rotate refresh tokens and end the session when one is used twice:
/// - one refresh per access token at a time, also across clients sharing the cache;
/// - a request rejected with a token that a finished refresh has already replaced retries with the new tokens
///   instead of refreshing again;
/// - a request rejected with a token that is no longer cached and was not refreshed into the cached one
///   (signed out or signed in again meanwhile) is neither refreshed nor retried: its response is returned as is;
/// - refreshed tokens are saved with `SecureCacheService.saveTokens(_:replacingAccessToken:)`,
///   unless the cache changed during the refresh.
///
/// Error handlers see the access token of the failed attempt in `APIErrorContext.accessToken`.
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
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		guard configs.isAuthEnabled else {
			return try await next(request, configs)
		}
		var tokens = try await currentTokens(request: request, configs: configs)
		if await TokenRefreshLocks.shared.waitIfLocked(tokens.accessToken) {
			tokens = try await currentTokens(request: request, configs: configs)
		}
		if
			let expiryDate = tokens.expiryDate,
			expiryDate < Date(),
			let renewed = try await renewedTokens(rejecting: tokens.accessToken, configs: configs)
		{
			tokens = renewed
		}
		let (result, status) = try await extractStatusCodeEvenFailed {
			try await send(request, with: tokens.accessToken, configs: configs, next: next)
		}
		guard
			expiredStatusCodes.contains(status),
			let renewed = try await renewedTokens(rejecting: tokens.accessToken, configs: configs)
		else {
			return try result.get()
		}
		return try await send(request, with: renewed.accessToken, configs: configs, next: next)
	}

	private func send<T>(
		_ request: HTTPRequestComponents,
		with accessToken: String,
		configs: APIClient.Configs,
		next: Next<T>
	) async throws -> (T, HTTPResponse) {
		var authorizedRequest = request
		try auth(accessToken).modifier(&authorizedRequest, configs)
		return try await next(authorizedRequest, configs.with(\.tokenRefresherAccessToken, accessToken))
	}

	private func currentTokens(
		request: HTTPRequestComponents,
		configs: APIClient.Configs
	) async throws -> CachedTokens {
		if let tokens = try await tokenCacheService.loadTokens() {
			return tokens
		}
		guard let requestToken, let url = request.url else {
			throw TokenNotFound(name: "accessToken")
		}
		return try await withThrowingSynchronizedAccess(id: url.host) { [tokenCacheService] in
			let (accessToken, refreshToken, expiryDate) = try await requestToken(configs)
			let tokens = CachedTokens(accessToken: accessToken, refreshToken: refreshToken, expiryDate: expiryDate)
			try await tokenCacheService.saveTokens(tokens)
			return tokens
		}
	}

	/// The tokens to use instead of `accessToken`, refreshing them if `accessToken` is still the cached one.
	/// `nil` when the cache no longer belongs to the session `accessToken` was issued in.
	private func renewedTokens(
		rejecting accessToken: String,
		configs: APIClient.Configs
	) async throws -> CachedTokens? {
		let outcome = try await renewal(rejecting: accessToken)
		guard case .refresh = outcome else {
			return outcome.tokens
		}
		await TokenRefreshLocks.shared.lock(accessToken)
		// Unstructured: a cancelled request must not drop tokens the server has already rotated.
		let result = await Task { [self] in
			try await refreshIfStillCached(accessToken, configs: configs)
		}.result
		await TokenRefreshLocks.shared.unlock(accessToken)
		return try result.get()
	}

	// Call with the lock for `accessToken` held.
	private func refreshIfStillCached(
		_ accessToken: String,
		configs: APIClient.Configs
	) async throws -> CachedTokens? {
		let outcome = try await renewal(rejecting: accessToken)
		guard case let .refresh(current) = outcome else {
			return outcome.tokens
		}
		let (newAccessToken, newRefreshToken, expiryDate) = try await refresh(current.refreshToken, configs)
		let renewed = CachedTokens(
			accessToken: newAccessToken,
			// A backend that does not rotate refresh tokens returns none.
			refreshToken: newRefreshToken ?? current.refreshToken,
			expiryDate: expiryDate
		)
		// Before the save: a request that reads the new token from the cache must find it as a successor.
		await TokenLineage.shared.record(renewed.accessToken, replacing: accessToken)
		if try await tokenCacheService.saveTokens(renewed, replacingAccessToken: accessToken) {
			return renewed
		}
		// A `refresh` closure may have saved the tokens itself; otherwise a sign-out or another sign-in won.
		return try await tokenCacheService.loadTokens()?.accessToken == renewed.accessToken ? renewed : nil
	}

	private func renewal(rejecting accessToken: String) async throws -> Renewal {
		guard let cached = try await tokenCacheService.loadTokens() else {
			return .unrecoverable
		}
		if cached.accessToken == accessToken {
			return .refresh(cached)
		}
		// Only a refresh in this session replaces a token; any other cached token comes from a new sign-in.
		if await TokenLineage.shared.isSuccessor(cached.accessToken, of: accessToken) {
			return .retry(cached)
		}
		return .unrecoverable
	}
}

private enum Renewal {

	/// The rejected token is still cached.
	case refresh(CachedTokens)
	/// A refresh has replaced the rejected token.
	case retry(CachedTokens)
	/// The cache belongs to another session or is empty.
	case unrecoverable

	var tokens: CachedTokens? {
		if case let .retry(tokens) = self { return tokens }
		return nil
	}
}

extension APIClient.Configs {

	var tokenRefresherAccessToken: String? {
		get { self[\.tokenRefresherAccessToken] ?? nil }
		set { self[\.tokenRefresherAccessToken] = newValue }
	}
}

/// One refresh per access token at a time, FIFO.
private final actor TokenRefreshLocks {

	static let shared = TokenRefreshLocks()

	// A present key is locked; its value holds the waiters.
	private var waiters: [String: [CheckedContinuation<Void, Never>]] = [:]

	func lock(_ key: String) async {
		guard waiters[key] != nil else {
			waiters[key] = []
			return
		}
		await withCheckedContinuation { waiters[key, default: []].append($0) }
	}

	func unlock(_ key: String) {
		guard var queue = waiters[key] else { return }
		guard !queue.isEmpty else {
			waiters[key] = nil
			return
		}
		let next = queue.removeFirst()
		waiters[key] = queue
		next.resume()
	}

	/// Returns `true` after waiting for a holder of the lock to release it.
	func waitIfLocked(_ key: String) async -> Bool {
		guard waiters[key] != nil else { return false }
		await lock(key)
		unlock(key)
		return true
	}
}

/// Which access token a refresh replaced with which, to tell a rotated token from a new sign-in.
private final actor TokenLineage {

	static let shared = TokenLineage()

	// Bounds memory; a request outliving this many refreshes is not retried after a 401.
	private static let limit = 64

	private var successors: [String: String] = [:]
	private var order: [String] = []

	func record(_ accessToken: String, replacing previous: String) {
		guard accessToken != previous else { return }
		if successors.updateValue(accessToken, forKey: previous) == nil {
			order.append(previous)
		}
		if order.count > Self.limit {
			successors[order.removeFirst()] = nil
		}
	}

	func isSuccessor(_ accessToken: String, of previous: String) -> Bool {
		var current = previous
		for _ in 0 ..< Self.limit {
			guard let successor = successors[current] else { return false }
			if successor == accessToken { return true }
			current = successor
		}
		return false
	}
}

public struct TokenNotFound: Error, CustomStringConvertible {

	public let name: String?

	public var description: String {
		"TokenNotFound\(name.map { ": \($0)" } ?? "")"
	}

	public init(name: String? = nil) {
		self.name = name
	}
}
