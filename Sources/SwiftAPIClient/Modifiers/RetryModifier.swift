import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes
import Logging
#if canImport(Darwin)
import Darwin
#else
import Glibc
#endif

public extension APIClient {

	/// Retries the request if it fails.
	@available(*, deprecated, message: "Use `retry()` modifier with `retryLimit(_:)` configuration instead.")
	func retry(limit: Int?) -> APIClient {
		httpClientMiddleware(RetryMiddleware(limit: limit))
	}
}

private struct RetryMiddleware: HTTPClientMiddleware {

	let limit: Int?

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		var count = 0
		func needRetry() -> Bool {
			if let limit {
				return count <= limit
			}
			return true
		}

		func retry() async throws -> (T, HTTPResponse) {
			count += 1
			return try await next(request, configs)
		}

		let response: HTTPResponse
		let data: T
		do {
			(data, response) = try await retry()
		} catch {
			if needRetry() {
				return try await retry()
			}
			throw error
		}
		if response.status.kind.isError, needRetry() {
			return try await retry()
		}
		return (data, response)
	}
}

public extension APIClient.Configs {

	/// The condition used to determine whether a request should be retried.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	var retryCondition: RetryRequestCondition {
		get { self[\.retryCondition] ?? .default }
		set { self[\.retryCondition] = newValue }
	}

	/// The maximum number of retries for a request. If `nil`, it will retry indefinitely. Default to 5.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	var retryLimit: Int? {
		get { self[\.retryLimit] ?? 5 }
		set { self[\.retryLimit] = newValue }
	}

	/// The interval between retries. It can be a fixed time interval or a closure that takes the current retry count and returns a time interval.
	/// Default to exponential backoff starting at 0.5 seconds, doubling each time, up to a maximum of 30 seconds.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	var retryInterval: (_ attempt: Int, _ response: HTTPResponse?) -> TimeInterval {
		get {
			self[\.retryInterval] ?? { attempt, response in
				min(0.5 * pow(2.0, Double(attempt)), 30.0)
			}
		}
		set { self[\.retryInterval] = newValue }
	}

	/// The date formatter used to parse the `Retry-After` header when it contains a date. By default, it uses the RFC 1123 format.
	/// - Tips: `DateFormatter` creation is expensive, so if you need a custom format, create the formatter once and reuse it.
	var retryAfterHeaderDateFormatter: DateFormatter {
		get { self[\.retryAfterHeaderDateFormatter] ?? defaultRetryAfterHeaderDateFormatter }
		set { self[\.retryAfterHeaderDateFormatter] = newValue }
	}

	/// The set of HTTP status codes that may include a `Retry-After` header. Default to `[429, 503]` due to RFC 7231.
	/// If a response has one of these status codes and includes a `Retry-After` header,
	/// the client will wait for the specified duration before retrying the request.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	var retryAfterHeaderStatusCodes: Set<HTTPResponse.Status> {
		get { self[\.retryAfterHeaderStatusCodes] ?? [.tooManyRequests, .serviceUnavailable] }
		set { self[\.retryAfterHeaderStatusCodes] = newValue }
	}

	/// Configuration for jitter applied to retry intervals.
	var retryJitterConfigs: RetryJitterConfigs {
		get { self[\.retryJitterConfigs] ?? RetryJitterConfigs() }
		set { self[\.retryJitterConfigs] = newValue }
	}

	/// The backoff policy used to determine how to handle global backoff scenarios, such as rate limiting.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	var retryBackoffPolicy: RetryBackoffPolicy {
		get { self[\.retryBackoffPolicy] ?? .default }
		set { self[\.retryBackoffPolicy] = newValue }
	}
}

public extension APIClient {

	/// Sets the condition used to determine whether a request should be retried.
	/// - Parameter condition: A closure that takes the request, the result of the request,
	/// - Note: This configuration works only if you use the `retry()` modifier.
	func retryCondition(_ condition: RetryRequestCondition) -> APIClient {
		configs(\.retryCondition, condition)
	}

	/// Sets the maximum number of retries for a request. If `nil`, it will retry indefinitely.
	/// - Parameter limit: The maximum number of retries.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	func retryLimit(_ limit: Int?) -> APIClient {
		configs(\.retryLimit, limit)
	}

	/// Sets the interval between retries. It can be a fixed time interval or a closure that takes the current retry count and returns a time interval.
	/// - Parameter interval: A closure that takes the current retry count (starting from 0
	/// - Note: This configuration works only if you use the `retry()` modifier.
	func retryInterval(_ interval: @escaping (Int, HTTPResponse?) -> TimeInterval) -> APIClient {
		configs(\.retryInterval, interval)
	}

	/// Sets a fixed interval between retries.
	/// - Parameter interval: The time interval to wait before the next retry.
	/// - Note: This configuration works only if you use the `retry()` modifier.
	func retryInterval(_ interval: TimeInterval) -> APIClient {
		retryInterval { _, _ in interval }
	}

	/// Sets the date formatter used to parse the `Retry-After` header when it contains a date. By default, it uses the RFC 1123 format.
	/// - Parameter formatter: The date formatter to use for parsing the `Retry-After`
	func retryAfterHeaderDateFormatter(_ formatter: DateFormatter) -> APIClient {
		configs(\.retryAfterHeaderDateFormatter, formatter)
	}

	/// Sets the backoff policy used to determine how to handle global backoff scenarios, such as rate limiting.
	/// - Parameter policy: The backoff policy to use.
	func retryBackoffPolicy(_ policy: RetryBackoffPolicy) -> APIClient {
		configs(\.retryBackoffPolicy, policy)
	}
}

public extension APIClient {

	/// Retries the request when necessary, based on the configured retry conditions and limits.
	///
	/// **Default Behavior:**
	/// - Retries safe HTTP methods (GET, HEAD, OPTIONS, TRACE) on network errors and transient failures
	/// - Uses exponential backoff starting at 0.5s, doubling each time, up to 30s maximum
	/// - Applies 10-20% jitter to prevent thundering herd
	/// - Respects `Retry-After` headers for 429 and 503 responses
	/// - Global backoff when rate limited (synchronizes requests to same host)
	/// - Maximum 5 retries by default
	///
	/// **Basic Usage:**
	/// ```swift
	/// // Use defaults
	/// let client = APIClient(baseURL: url).retry()
	///
	/// // Custom limit
	/// let client = APIClient(baseURL: url)
	///     .retry()
	///     .retryLimit(3)
	///
	/// // Fixed interval
	/// let client = APIClient(baseURL: url)
	///     .retry()
	///     .retryInterval(2.0)
	///
	/// // Custom interval strategy
	/// let client = APIClient(baseURL: url)
	///     .retry()
	///     .retryInterval { attempt, response in
	///         min(pow(2.0, Double(attempt)), 60.0)
	///     }
	/// ```
	///
	/// **Retry Conditions:**
	///
	/// Built-in conditions:
	/// - `.default` - Safe methods + (network errors OR transient status codes)
	/// - `.requestFailed` - Network errors (e.g., timeouts, connection lost)
	/// - `.requestMethodIsSafe` - Only safe methods (GET, HEAD, OPTIONS, TRACE)
	/// - `.retryStatusCode` - Transient codes (408, 421, 429, 500, 502, 503, 504, 509)
	/// - `.rateLimitExceeded` - 429 Too Many Requests
	/// - `.methods(...)` - Specific HTTP methods
	/// - `.statusCodes(...)` - Specific status codes
	///
	/// ```swift
	/// // Retry POST on rate limit
	/// client.retry()
	///     .retryCondition(.and(.methods(.post), .rateLimitExceeded))
	///
	/// // Retry on specific codes
	/// client.retry()
	///     .retryCondition(.statusCodes(429, 503, 504))
	///
	/// // Complex conditions
	/// client.retry()
	///     .retryCondition(
	///         .and(
	///             .methods(.get, .post),
	///             .or(.requestFailed, .statusCodes(.serviceUnavailable))
	///         )
	///     )
	/// ```
	///
	/// **Retry-After Header:**
	///
	/// Automatically respects `Retry-After` headers:
	/// ```swift
	/// // Configure status codes to check
	/// client.retry()
	///     .configs(\.retryAfterHeaderStatusCodes, [.tooManyRequests])
	///
	/// // Custom date formatter for date-based headers
	/// let formatter = DateFormatter()
	/// formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
	/// client.retry()
	///     .retryAfterHeaderDateFormatter(formatter)
	/// ```
	///
	/// **Global Backoff:**
	///
	/// Rate limit responses trigger global backoff for all requests to the same scope:
	/// ```swift
	/// // Default: same host
	/// client.retry()
	///
	/// // Custom scope (e.g., host + API key)
	/// client.retry()
	///     .retryBackoffPolicy(
	///         RetryBackoffPolicy(
	///             scopeHash: { request in
	///                 guard let host = request.urlComponents.host else { return nil }
	///                 return "\(host):\(request.headerFields[.authorization] ?? "")"
	///             },
	///             isGlobalBackoff: { _, response in
	///                 response.status == .tooManyRequests
	///             }
	///         )
	///     )
	/// ```
	///
	/// **Jitter:**
	///
	/// Randomizes retry intervals to prevent thundering herd:
	/// ```swift
	/// // Default: 10-20% jitter, 5ms min, 1s max
	/// client.retry()
	///
	/// // Custom jitter
	/// client.retry()
	///     .configs(\.retryJitterConfigs, RetryJitterConfigs(
	///         fraction: 0.05...0.15,
	///         minNs: 10_000_000,
	///         maxNs: 500_000_000
	///     ))
	/// ```
	///
	/// **Per-Condition Rules:**
	///
	/// Multiple `retry` calls stack into independent rules instead of overwriting each other.
	/// Each rule carries its own condition, limit, and interval, and keeps its own attempt counter,
	/// so different failures can be retried with different policies:
	/// ```swift
	/// client
	///     .retry()                                       // sensible defaults, as a fallback
	///     .retry(when: .rateLimitExceeded, limit: 10)    // 429: more attempts
	/// ```
	/// When a request fails, the most recently added matching rule wins (last-match), so a child
	/// client can override an inherited rule simply by adding its own. Use ``noRetry()`` to drop
	/// all inherited rules and start over.
	///
	/// - Note: Order-dependent - only catches errors from previous modifiers, not following ones.
	/// - Tip: Customize via `retryCondition`, `retryLimit`, `retryInterval`, `retryBackoffPolicy`,
	/// `retryAfterHeaderStatusCodes`, `retryAfterHeaderDateFormatter`, and `retryJitterConfigs`.
	func retry() -> APIClient {
		addRetryRule(RetryRule())
	}

	/// Adds a retry rule for a specific condition, with optional per-rule limit and interval.
	///
	/// Unlike ``retryCondition(_:)``/``retryLimit(_:)``, which configure the global fallback used by
	/// rules that don't override them, this installs an additional, independently-counted rule.
	/// Calling this is enough on its own - no separate ``retry()`` is required.
	///
	/// ```swift
	/// client
	///     .retry(when: .rateLimitExceeded, limit: 10)    // 429: respect Retry-After, up to 10
	///     .retry(when: .requestFailed, limit: 3)         // network errors: 3 retries
	/// ```
	///
	/// - Parameters:
	///   - condition: The condition that selects this rule.
	///   - limit: The maximum number of retries for this rule. `nil` inherits the global `retryLimit`.
	///   - interval: The interval strategy for this rule. `nil` inherits the global `retryInterval`.
	/// - Note: When several rules match the same failure, the most recently added one wins.
	func retry(
		when condition: RetryRequestCondition,
		limit: Int? = nil,
		interval: ((_ attempt: Int, _ response: HTTPResponse?) -> TimeInterval)? = nil
	) -> APIClient {
		addRetryRule(RetryRule(condition: condition, limit: limit, interval: interval))
	}

	/// Removes all retry rules, including those inherited from a parent client.
	///
	/// Useful for a child client that must override the inherited retry behaviour instead of merging
	/// with it: `parent.noRetry().retry(when: ...)`.
	func noRetry() -> APIClient {
		configs { $0.retryRules = [] }
	}

	private func addRetryRule(_ rule: RetryRule) -> APIClient {
		configs {
			$0.retryRules.append(rule)
			// Install the middleware exactly once, regardless of how many rules are added.
			if !$0.retryMiddlewareInstalled {
				$0.retryMiddlewareInstalled = true
				$0.httpClientArrayMiddleware.middlewares.append(SmartRetryMiddleware())
			}
		}
	}
}

/// A single retry policy: a condition plus the parameters applied when it matches.
///
/// `nil` fields inherit the corresponding global configuration (`retryCondition`, `retryLimit`,
/// `retryInterval`), so a default-constructed rule behaves exactly like the legacy single-policy retry.
// @ai-generated(guided)
struct RetryRule {

	/// The condition selecting this rule. `nil` inherits `configs.retryCondition`.
	var condition: RetryRequestCondition?

	/// The per-rule retry limit. `nil` inherits `configs.retryLimit` (which itself may be `nil` for unlimited).
	var limit: Int?

	/// The per-rule interval strategy. `nil` inherits `configs.retryInterval`.
	var interval: ((_ attempt: Int, _ response: HTTPResponse?) -> TimeInterval)?

	init(
		condition: RetryRequestCondition? = nil,
		limit: Int? = nil,
		interval: ((_ attempt: Int, _ response: HTTPResponse?) -> TimeInterval)? = nil
	) {
		self.condition = condition
		self.limit = limit
		self.interval = interval
	}
}

private extension APIClient.Configs {

	/// The ordered list of retry rules. Evaluated last-to-first so later rules win on overlap.
	var retryRules: [RetryRule] {
		get { self[\.retryRules] ?? [] }
		set { self[\.retryRules] = newValue }
	}

	/// Whether the retry middleware has already been added to the chain, to keep installation idempotent.
	var retryMiddlewareInstalled: Bool {
		get { self[\.retryMiddlewareInstalled] ?? false }
		set { self[\.retryMiddlewareInstalled] = newValue }
	}
}

/// A condition that determines whether a request should be retried based on the request, the result of the request, and the client configurations.
public struct RetryRequestCondition: Sendable {

	private let condition: @Sendable (HTTPRequestComponents, HTTPResponse?, Error?, APIClient.Configs) -> Bool

	/// Initializes a new `RetryRequestCondition` with a custom condition closure.
	/// - Parameters:
	///   - condition: A closure that takes the request, the result of the request, and the client configs, and returns a Boolean indicating whether to retry the request.
	public init(
		_ condition: @escaping @Sendable (_ request: HTTPRequestComponents, _ result: HTTPResponse?, _ error: Error?, _ configs: APIClient.Configs) -> Bool
	) {
		self.condition = condition
	}

	/// Determines whether the request should be retried based on the provided condition.
	/// - Parameters:
	///   - request: The original HTTP request components.
	///   - result: The result of the HTTP request, which can be either a successful response or an error.
	///   - configs: The configurations of the API client.
	public func shouldRetry(
		request: HTTPRequestComponents,
		response: HTTPResponse?,
		error: Error?,
		configs: APIClient.Configs
	) -> Bool {
		condition(request, response, error, configs)
	}

	/// Combines two `RetryRequestCondition` instances using a logical AND operation.
	/// The resulting condition will only return `true` if both conditions return `true`.
	/// - Parameter other: Another `RetryRequestCondition` to combine with.
	public func and(_ other: RetryRequestCondition) -> RetryRequestCondition {
		RetryRequestCondition { request, response, error, configs in
			shouldRetry(request: request, response: response, error: error, configs: configs)
				&& other.shouldRetry(request: request, response: response, error: error, configs: configs)
		}
	}

	/// Combines multiple `RetryRequestCondition` instances using a logical AND operation.
	/// The resulting condition will only return `true` if all conditions return `true`.
	/// - Parameter conditions: An array of `RetryRequestCondition` instances to combine.
	/// - Returns: A new `RetryRequestCondition` that represents the combined conditions.
	public static func and(_ conditions: RetryRequestCondition...) -> RetryRequestCondition {
		and(conditions)
	}

	/// Combines multiple `RetryRequestCondition` instances using a logical AND operation.
	/// The resulting condition will only return `true` if all conditions return `true`.
	/// - Parameter conditions: An array of `RetryRequestCondition` instances to combine.
	/// - Returns: A new `RetryRequestCondition` that represents the combined conditions.
	public static func and(_ conditions: [RetryRequestCondition]) -> RetryRequestCondition {
		RetryRequestCondition { request, response, error, configs in
			for condition in conditions {
				if !condition.shouldRetry(request: request, response: response, error: error, configs: configs) {
					return false
				}
			}
			return true
		}
	}

	/// Combines multiple `RetryRequestCondition` instances using a logical OR operation.
	/// The resulting condition will return `true` if any of the conditions return `true`.
	/// - Parameter conditions: An array of `RetryRequestCondition` instances to combine.
	/// - Returns: A new `RetryRequestCondition` that represents the combined conditions.
	public static func or(_ conditions: RetryRequestCondition...) -> RetryRequestCondition {
		or(conditions)
	}

	/// Combines multiple `RetryRequestCondition` instances using a logical OR operation.
	/// The resulting condition will return `true` if any of the conditions return `true`.
	/// - Parameter conditions: An array of `RetryRequestCondition` instances to combine.
	/// - Returns: A new `RetryRequestCondition` that represents the combined conditions.
	public static func or(_ conditions: [RetryRequestCondition]) -> RetryRequestCondition {
		RetryRequestCondition { request, response, error, configs in
			for condition in conditions {
				if condition.shouldRetry(request: request, response: response, error: error, configs: configs) {
					return true
				}
			}
			return false
		}
	}

	/// Combines two `RetryRequestCondition` instances using a logical OR operation.
	/// The resulting condition will return `true` if either condition returns `true`.
	/// - Parameter other: Another `RetryRequestCondition` to combine with.
	public func or(_ other: RetryRequestCondition) -> RetryRequestCondition {
		RetryRequestCondition { request, response, error, configs in
			shouldRetry(request: request, response: response, error: error, configs: configs)
				|| other.shouldRetry(request: request, response: response, error: error, configs: configs)
		}
	}

	/// The default `RetryRequestCondition`.
	///
	/// Retries when **either**:
	/// - the method is safe (GET, HEAD, OPTIONS, TRACE) **and** the request failed due to a network error
	///   or a transient status code (`requestFailed` or `retryStatusCode`); or
	/// - the response is `429 Too Many Requests` or `503 Service Unavailable`, **regardless of method**.
	///
	/// The second branch covers the common case where the server rejected the request *before processing it*
	/// (rate limiting / temporary unavailability), so retrying is safe even for non-idempotent methods like POST.
	public static var `default`: RetryRequestCondition {
		.or(
			.and(
				.requestMethodIsSafe,
				.or(
					.requestFailed,
					.retryStatusCode
				)
			),
			.statusCodes(.tooManyRequests, .serviceUnavailable)
		)
	}

	/// A `RetryRequestCondition` that retries safe HTTP methods (like GET) when the request fails due to network errors.
	public static let requestFailed = RetryRequestCondition { request, response, error, _ in
		switch error {
		case nil:
			return false
		case let .some(error):
			return isRetryable(error)
		}
	}

	/// A `RetryRequestCondition` that retries the request when the HTTP method is considered safe (e.g., GET, HEAD, OPTIONS).
	public static let requestMethodIsSafe = RetryRequestCondition { request, _, _, _ in
		request.method.isSafe
	}

	/// A `RetryRequestCondition` that retries the request when the response status code indicates a failure that is typically transient.
	public static let retryStatusCode = RetryRequestCondition.statusCodes(408, 421, 429, 500, 502, 503, 504, 509)

	/// A `RetryRequestCondition` that retries the request when the response status code is `429 Too Many Requests`.
	public static let rateLimitExceeded = RetryRequestCondition.statusCodes(.tooManyRequests)

	/// A `RetryRequestCondition` that retries requests with defined HTTP methods.
	public static func methods(_ methods: HTTPRequest.Method...) -> RetryRequestCondition {
		Self.methods(Set(methods))
	}

	/// A `RetryRequestCondition` that retries requests with defined HTTP methods.
	public static func methods(_ methods: Set<HTTPRequest.Method>) -> RetryRequestCondition {
		RetryRequestCondition { request, _, _, _ in
			methods.contains(request.method)
		}
	}

	/// A `RetryRequestCondition` that retries when the response status code is one of the specified codes.
	public static func statusCodes(_ codes: HTTPResponse.Status...) -> RetryRequestCondition {
		statusCodes(Set(codes))
	}

	/// A `RetryRequestCondition` that retries when the response status code is one of the specified codes.
	public static func statusCodes(_ codes: Set<HTTPResponse.Status>) -> RetryRequestCondition {
		RetryRequestCondition { _, response, _, _ in
			if let response {
				return codes.contains(response.status)
			}
			return false
		}
	}
}

/// Backoff policy described with closures.
public struct RetryBackoffPolicy: Sendable {

	/// Hash all requests that must share the same cooldown window.
	/// Example: host-only, or host+token, or host+bucket(path prefix).
	let scopeHash: @Sendable (_ request: HTTPRequestComponents) -> AnyHashable?

	/// Decide if the response must trigger a global backoff for the scope.
	let isGlobalBackoff: @Sendable (_ request: HTTPRequestComponents, _ response: HTTPResponse) -> Bool

	public init(
		scopeHash: @escaping @Sendable (_ request: HTTPRequestComponents) -> AnyHashable?,
		isGlobalBackoff: @escaping @Sendable (_ request: HTTPRequestComponents, _ response: HTTPResponse) -> Bool
	) {
		self.isGlobalBackoff = isGlobalBackoff
		self.scopeHash = scopeHash
	}

	public static let `default` = RetryBackoffPolicy { req in
		req.urlComponents.host
	} isGlobalBackoff: { _, response in
		Set([429, 503]).contains(response.status.code)
	}
}

private struct SmartRetryMiddleware: HTTPClientMiddleware {

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		let rules = configs.retryRules
		// `noRetry()` clears all rules; with nothing to do, behave as a transparent pass-through
		// and don't participate in any global backoff window.
		guard !rules.isEmpty else {
			return try await next(request, configs)
		}

		let backoffPolicy = configs.retryBackoffPolicy
		if let hash = backoffPolicy.scopeHash(request) {
			if let interval = await waitForSynchronizedAccess(id: hash, of: UInt64.self) {
				try await Task.sleep(nanoseconds: configs.retryJitterConfigs.delay(for: interval))
			}
		}

		// Per-rule attempt counters: each rule's `limit` is enforced independently.
		var counts = [Int](repeating: 0, count: rules.count)
		var response: HTTPResponse?
		var retryAfterHeader: TimeInterval = 0

		/// Returns the index of the rule that should govern a retry for the current outcome, or `nil` to stop.
		/// Rules are evaluated last-to-first, so the most recently added matching rule wins. Once a rule claims
		/// the outcome, its limit is final - we don't fall through to a more general rule.
		func ruleForRetry(_ error: Error?) -> Int? {
			for index in stride(from: rules.count - 1, through: 0, by: -1) {
				let condition = rules[index].condition ?? configs.retryCondition
				guard condition.shouldRetry(request: request, response: response, error: error, configs: configs) else {
					continue
				}
				let limit = rules[index].limit ?? configs.retryLimit
				if let limit, counts[index] >= limit {
					return nil
				}
				return index
			}
			return nil
		}

		func sleepBeforeRetry(rule index: Int) async throws {
			let attempt = counts[index]
			counts[index] += 1
			let intervalFn = rules[index].interval ?? configs.retryInterval
			let seconds = max(retryAfterHeader, intervalFn(attempt, response))
			let nanoseconds = UInt64(max(0, seconds) * 1_000_000_000)
			guard nanoseconds > 0 else { return }
			if let response, let hash = backoffPolicy.scopeHash(request), backoffPolicy.isGlobalBackoff(request, response) {
				Logger(label: "SwiftAPIClient")
					.trace("Backing off requests to '\(hash.base)' for \(Double(nanoseconds) / 1_000_000_000) seconds due to \(response.status) status code.")
				_ = try await withThrowingSynchronizedAccess(id: hash) {
					try await Task.sleep(nanoseconds: nanoseconds)
					return nanoseconds
				}
			} else {
				try await Task.sleep(nanoseconds: nanoseconds)
			}
		}

		while true {
			let result: Result<(T, HTTPResponse), Error>
			do {
				let (extracted, rsp) = try await extractResponseEvenFailed {
					try await next(request, configs)
				}
				response = rsp
				result = extracted
			} catch {
				// Network-level error: no response to inspect for conditions or Retry-After.
				response = nil
				result = .failure(error)
			}

			retryAfterHeader = 0
			if let response, configs.retryAfterHeaderStatusCodes.contains(response.status) {
				retryAfterHeader = response.headerFields[.retryAfter].flatMap {
					decodeRetryAfterHeader($0, formatter: configs.retryAfterHeaderDateFormatter)
				} ?? 0
			}

			switch result {
			case let .success(value):
				guard let index = ruleForRetry(nil) else {
					return value
				}
				try await sleepBeforeRetry(rule: index)
			case let .failure(error):
				guard let index = ruleForRetry(error) else {
					throw error
				}
				try await sleepBeforeRetry(rule: index)
			}
		}
	}
}

/// Configuration for jitter applied to retry intervals.
public struct RetryJitterConfigs: Hashable, Sendable {

	/// The fraction range of the base interval to use for jitter.
	public var fraction: ClosedRange<Double>

	/// The minimum jitter in nanoseconds.
	public var minNs: UInt64

	/// The maximum jitter in nanoseconds.
	public var maxNs: UInt64

	public init(
		fraction: ClosedRange<Double> = 0.1 ... 0.2,
		minNs: UInt64 = 5_000_000, // 5 ms
		maxNs: UInt64 = 1_000_000_000 // 1 s
	) {
		self.fraction = fraction
		self.minNs = minNs
		self.maxNs = maxNs
	}

	/// Applies jitter to the given interval.
	@inline(__always)
	public func delay(for interval: UInt64) -> UInt64 {
		guard interval > 0 else { return 0 }
		let p = Double.random(in: fraction)
		guard p > 0 else { return 0 }
		let raw = UInt64(Double(interval) * p)
		return min(max(raw, minNs), maxNs)
	}

	/// No jitter applied.
	public static let off = RetryJitterConfigs(fraction: 0 ... 0, minNs: 0, maxNs: 0)
}

private func decodeRetryAfterHeader(_ value: String, formatter: DateFormatter) -> TimeInterval? {
	// seconds
	if let seconds = TimeInterval(value) {
		return seconds
	}

	// RFC 1123 date
	if let date = formatter.date(from: value) {
		let delta = date.timeIntervalSinceNow
		return delta > 0 ? delta : 0
	}

	Logger(label: "SwiftAPIClient").warning("Failed to parse Retry-After header: '\(value)' using '\(formatter.dateFormat ?? "nil")' format.")
	return nil
}

private let defaultRetryAfterHeaderDateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	// RFC 1123
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "EEE',' dd MMM yyyy HH:mm:ss zzz"
	return formatter
}()

private struct ImpossibleError: Error {}

/// Проверка: ошибка временная, стоит повторить.
func isRetryable(_ error: Error) -> Bool {
	if let apiClientError = error as? APIClientError {
		return isRetryable(apiClientError.error)
	}
	if error is TimeoutError {
		return true
	}

	// 1. Foundation / URLSession (iOS, macOS)
	if let urlError = error as? URLError {
		switch urlError.code {
		case .timedOut,
		     .cannotFindHost,
		     .cannotConnectToHost,
		     .networkConnectionLost,
		     .dnsLookupFailed,
		     .notConnectedToInternet:
			return true
		default:
			return false
		}
	}

	// 2. POSIX errno (Linux / NIO / CFNetwork нижний уровень)
	if let posix = (error as NSError?)?.code {
		switch Int32(posix) {
		case ETIMEDOUT,
		     ECONNRESET,
		     ECONNABORTED,
		     ECONNREFUSED,
		     EPIPE,
		     ENETDOWN,
		     ENETUNREACH,
		     EHOSTDOWN,
		     EHOSTUNREACH:
			return true
		default:
			break
		}
	}

	// 3. SwiftNIO/AsyncHTTPClient ошибки (если используешь)
	let nsError = error as NSError
	if nsError.domain == "AsyncHTTPClient.HTTPClientError" {
		switch nsError.code {
		case 1, // .connectTimeout
		     2, // .readTimeout
		     3, // .writeTimeout
		     4: // .remoteConnectionClosed
			return true
		default:
			break
		}
	}
	return false
}
