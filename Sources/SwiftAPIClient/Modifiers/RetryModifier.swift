import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes

public extension APIClient {
	
	/// Retries the request if it fails.
	/// - Parameters:
	///   - limit: The maximum number of retries. If `nil`, it will retry indefinitely.
	///   - interval: The time interval to wait before the next retry. Defaults to 0 seconds.
	///   - condition: A closure that takes the request, the result of the request, and the client configs, and returns a Boolean indicating whether to retry the request.
	///    If not provided, it defaults to retrying safe methods (like GET) on error status codes or network errors.
	///   - retryKey: A closure that takes the request and returns a key used to group retries. Requests with the same key will share retry decisions.
	///   For example, if a rate limit error occurs for one request, all other requests with the same key (such as the same host) will be delayed. Defaults to `nil`, meaning no grouping.
	/// - Note: Like any modifier, this is order dependent. It takes in account only error from previous modifiers but not the following ones.
	func retry(
		retryKey: ((HTTPRequestComponents) -> AnyHashable)? = nil,
		when condition: RetryRequestCondition = .requestFailed,
		limit: Int?,
		interval: TimeInterval = 0
	) -> APIClient {
		retry(when: condition,limit: limit, interval: { _ in interval }, retryKey: retryKey)
	}
	
	/// Retries the request if it fails.
	/// - Parameters:
	///   - limit: The maximum number of retries. If `nil`, it will retry indefinitely.
	///   - interval: A closure that takes the current retry count (starting from 0) and returns the time interval to wait before the next retry. If not provided, it defaults to 0 seconds.
	///   - condition: A closure that takes the request, the result of the request, and the client configs, and returns a Boolean indicating whether to retry the request.
	///   If not provided, it defaults to retrying safe methods (like GET) on error status codes or network errors.
	///   - retryKey: A closure that takes the request and returns a key used to group retries. Requests with the same key will share retry decisions.
	///   For example, if a rate limit error occurs for one request, all other requests with the same key (such as the same host) will be delayed. Defaults to `nil`, meaning no grouping.
	/// - Note: Like any modifier, this is order dependent. It takes in account only error from previous modifiers but not the following ones.
	func retry(
		when condition: RetryRequestCondition = .requestFailed,
		limit: Int?,
		interval: @escaping (Int) -> TimeInterval,
		retryKey: ((HTTPRequestComponents) -> AnyHashable)? = nil
	) -> APIClient {
		httpClientMiddleware(RetryMiddleware(retryKey: retryKey, limit: limit, interval: interval, condition: condition))
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
	
	/// Combines two `RetryRequestCondition` instances using a logical OR operation.
	/// The resulting condition will return `true` if either condition returns `true`.
	/// - Parameter other: Another `RetryRequestCondition` to combine with.
	public func or(_ other: RetryRequestCondition) -> RetryRequestCondition {
		RetryRequestCondition { request, result, configs in
			self.shouldRetry(request: request, result: result, configs: configs)
			|| other.shouldRetry(request: request, result: result, configs: configs)
		}
	}

	/// A `RetryRequestCondition` that retries safe HTTP methods (like GET) when the request fails due to error status codes or network errors.
	public static let requestFailed = RetryRequestCondition { request, result, _ in
		guard request.method.isSafe else {
			return false
		}
		switch result {
		case let .success(response):
			return response.status.kind.isError
		case let .failure(error):
			return !(error is CancellationError)
		}
	}

	/// A `RetryRequestCondition` that retries the request when the response status code is `429 Too Many Requests`.
	public static let rateLimitExceeded = RetryRequestCondition.requestFailed.and(.statusCodes(.tooManyRequests))
	
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
	let limit: Int?
	let interval: (Int) -> TimeInterval
	let condition: RetryRequestCondition

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
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
				response.headerFields[.retryAfter]
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

private struct ImpossibleError: Error {}
