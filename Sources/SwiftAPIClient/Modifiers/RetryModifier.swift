import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes
import Logging

public extension APIClient.Configs {
	
	/// The condition used to determine whether a request should be retried.
	/// - Note: This configuration works only if you use the `retry` modifier.
	var retryCondition: RetryRequestCondition {
		get { self[\.retryCondition] ?? .default }
		set { self[\.retryCondition] = newValue }
	}
	
	/// The maximum number of retries for a request. If `nil`, it will retry indefinitely.
	/// - Note: This configuration works only if you use the `retry` modifier.
	var retryLimit: Int? {
		get { self[\.retryLimit] }
		set { self[\.retryLimit] = newValue }
	}

	/// The interval between retries. It can be a fixed time interval or a closure that takes the current retry count and returns a time interval.
	/// - Note: This configuration works only if you use the `retry` modifier.
	var retryInterval: (Int) -> TimeInterval {
		get { self[\.retryInterval] ?? { _ in 0 } }
		set { self[\.retryInterval] = newValue }
	}
	
	/// The date formatter used to parse the `Retry-After` header when it contains a date. By default, it uses the RFC 1123 format.
	/// - Tips: `DateFormatter` creation is expensive, so if you need a custom format, create the formatter once and reuse it.
	var retryAfterHeaderDateFormatter: DateFormatter {
		get { self[\.retryAfterHeaderDateFormatter] ?? defaultRetryAfterHeaderDateFormatter }
		set { self[\.retryAfterHeaderDateFormatter] = newValue }
	}
}

public extension APIClient {
	
	/// Sets the condition used to determine whether a request should be retried.
	/// - Parameter condition: A closure that takes the request, the result of the request,
	/// - Note: This configuration works only if you use the `retry` modifier.
	func retryCondition(_ condition: RetryRequestCondition) -> APIClient {
		configs(\.retryCondition, condition)
	}
	
	/// Sets the maximum number of retries for a request. If `nil`, it will retry indefinitely.
	/// - Parameter limit: The maximum number of retries.
	/// - Note: This configuration works only if you use the `retry` modifier.
	func retryLimit(_ limit: Int?) -> APIClient {
		configs(\.retryLimit, limit)
	}
	
	/// Sets the interval between retries. It can be a fixed time interval or a closure that takes the current retry count and returns a time interval.
	/// - Parameter interval: A closure that takes the current retry count (starting from 0
	/// - Note: This configuration works only if you use the `retry` modifier.
	func retryInterval(_ interval: @escaping (Int) -> TimeInterval) -> APIClient {
		configs(\.retryInterval, interval)
	}
	
	/// Sets a fixed interval between retries.
	/// - Parameter interval: The time interval to wait before the next retry.
	/// - Note: This configuration works only if you use the `retry` modifier.
	func retryInterval(_ interval: TimeInterval) -> APIClient {
		retryInterval { _ in interval }
	}
}

public extension APIClient {
	
	/// Retries the request if it fails.
	/// - Parameters:
	///   - retryKey: A closure that takes the request and returns a key used to group retries. Requests with the same key will share retry decisions.
	///   For example, if a rate limit error occurs for one request, all other requests with the same key (such as the same host) will be delayed. Defaults to `nil`, meaning no grouping.
	/// - Note: Like any modifier, this is order dependent. It takes in account only error from previous modifiers but not the following ones.
	/// - Tip: You can customize the retry behavior by setting the `retryCondition`, `retryLimit`, and `retryInterval` configurations. Also, there is `\.retryAfterHeaderDateFormatter` configuration to customize parsing of `Retry-After` header.
	func retry(
		retryKey: ((HTTPRequestComponents) -> AnyHashable)? = nil
	) -> APIClient {
		httpClientMiddleware(RetryMiddleware(retryKey: retryKey))
	}
}

/// A condition that determines whether a request should be retried based on the request, the result of the request, and the client configurations.
public struct RetryRequestCondition {
	
	private let condition: (HTTPRequestComponents, Result<HTTPResponse, Error>, APIClient.Configs) -> Bool
	
	/// Initializes a new `RetryRequestCondition` with a custom condition closure.
	/// - Parameters:
	///   - condition: A closure that takes the request, the result of the request, and the client configs, and returns a Boolean indicating whether to retry the request.
	public init(
		_ condition: @escaping (_ request: HTTPRequestComponents, _ result: Result<HTTPResponse, Error>, _ configs: APIClient.Configs) -> Bool
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
		result: Result<HTTPResponse, Error>,
		configs: APIClient.Configs
	) -> Bool {
		condition(request, result, configs)
	}
	
	/// Combines two `RetryRequestCondition` instances using a logical AND operation.
	/// The resulting condition will only return `true` if both conditions return `true`.
	/// - Parameter other: Another `RetryRequestCondition` to combine with.
	public func and(_ other: RetryRequestCondition) -> RetryRequestCondition {
		RetryRequestCondition { request, result, configs in
			self.shouldRetry(request: request, result: result, configs: configs)
			&& other.shouldRetry(request: request, result: result, configs: configs)
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
		RetryRequestCondition { request, result, configs in
			for condition in conditions {
				if !condition.shouldRetry(request: request, result: result, configs: configs) {
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
		RetryRequestCondition { request, result, configs in
			for condition in conditions {
				if condition.shouldRetry(request: request, result: result, configs: configs) {
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
		RetryRequestCondition { request, result, configs in
			self.shouldRetry(request: request, result: result, configs: configs)
			|| other.shouldRetry(request: request, result: result, configs: configs)
		}
	}

	/// The default `RetryRequestCondition` that retries safe HTTP methods (like GET) when the request fails due to error status codes or network errors.
	/// This condition combines the following:
	/// - `requestMethodIsSafe`: Ensures that only safe HTTP methods are retried.
	/// - `requestFailed`: Retries when the request fails due to network errors.
	/// - `retryableStatusCode`: Retries when the response status code indicates a transient failure.
	/// This default behavior is suitable for most scenarios where idempotent requests should be retried on failure.
	public static var `default`: RetryRequestCondition {
		.and(
			.requestMethodIsSafe,
			.or(
				.requestFailed,
				.retryableStatusCode
			)
		)
	}

	/// A `RetryRequestCondition` that retries safe HTTP methods (like GET) when the request fails due to error status codes or network errors.
	public static let requestFailed = RetryRequestCondition { request, result, _ in
		switch result {
		case let .success(response):
			return false
		case let .failure(error):
			return !(error is CancellationError)
		}
	}
	
	/// A `RetryRequestCondition` that retries the request when the HTTP method is considered safe (e.g., GET, HEAD, OPTIONS).
	public static let requestMethodIsSafe = RetryRequestCondition { request, _, _ in
		request.method.isSafe
	}
	
	/// A `RetryRequestCondition` that retries the request when the response status code indicates a failure that is typically transient.
	public static let retryableStatusCode = RetryRequestCondition.statusCodes([408, 421, 429, 500, 502, 503, 504, 509])

	/// A `RetryRequestCondition` that retries the request when the response status code is `429 Too Many Requests`.
	public static let rateLimitExceeded = RetryRequestCondition.statusCodes(.tooManyRequests)
	
	/// A `RetryRequestCondition` that retries requests with defined HTTP methods.
	public static func methods(_ methods: HTTPRequest.Method...) -> RetryRequestCondition {
		Self.methods(Set(methods))
	}
	
	/// A `RetryRequestCondition` that retries requests with defined HTTP methods.
	public static func methods(_ methods: Set<HTTPRequest.Method>) -> RetryRequestCondition {
		RetryRequestCondition { request, _, _ in
			methods.contains(request.method)
		}
	}
	
	/// A `RetryRequestCondition` that retries when the response status code is one of the specified codes.
	public static func statusCodes(_ codes: HTTPResponse.Status...) -> RetryRequestCondition {
		Self.statusCodes(Set(codes))
	}
	
	/// A `RetryRequestCondition` that retries when the response status code is one of the specified codes.
	public static func statusCodes(_ codes: Set<HTTPResponse.Status>) -> RetryRequestCondition {
		RetryRequestCondition { _, response, _ in
			if case let .success(response) = response {
				return codes.contains(response.status)
			}
			return true
		}
	}
}

private struct RetryMiddleware: HTTPClientMiddleware {

	let retryKey: ((HTTPRequestComponents) -> AnyHashable)?

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		let condition = configs.retryCondition
		let limit = configs.retryLimit
		let interval = configs.retryInterval
		if let retryKey {
			await waitForSynchronizedAccess(id: retryKey(request), of: Void.self)
		}
		var count = 0
		var retryAfterHeader: TimeInterval = 0
		
		func needRetry(_ result: Result<HTTPResponse, Error>) -> Bool {
			guard condition.shouldRetry(request: request, result: result, configs: configs) else {
				return false
			}
			if let limit {
				return count <= limit
			}
			return true
		}

		func retry() async throws -> (T, HTTPResponse) {
			if count > 0 {
				let interval = UInt64(max(retryAfterHeader, interval(count - 1)) * 1_000_000_000)
				if interval > 0 {
					if let retryKey {
						try await withThrowingSynchronizedAccess(id: retryKey(request)) {
							try await Task.sleep(nanoseconds: interval)
						}
					} else {
						try await Task.sleep(nanoseconds: interval)
					}
				}
			}
			count += 1
			
			return try await next(request, configs)
		}

		while true {
			do {
			 let (data, response) = try await retry()
				retryAfterHeader = response.headerFields[.retryAfter].flatMap {
					decodeRetryAfterHeader($0, formatter: configs.retryAfterHeaderDateFormatter)
				} ?? 0
				if !needRetry(.success(response)) {
					return (data, response)
				}
		 } catch {
			 if !needRetry(.failure(error)) {
				 throw error
			 }
		 }
		}
		throw ImpossibleError()
	}
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
