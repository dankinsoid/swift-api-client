import Foundation
import HTTPTypes

public extension APIClient {

	/// When the rate limit is exceeded, the request will be repeated after the specified interval and all requests with the same identifier will be suspended.
	/// - Parameters:
	///  - id: The identifier to use for rate limiting. Default to the base URL of the request.
	///  - interval: The interval to wait before repeating the request. Default to 30 seconds.
	///  - statusCodes: The set of status codes that indicate a rate limit exceeded. Default to `[429]`.
	///  - methods: The set of HTTP methods to retry. If `nil`, all methods are retried. Default to `nil`.
	///  - maxRepeatCount: The maximum number of times the request can be repeated. Default to 3.
	func waitIfRateLimitExceeded<ID: Hashable>(
		id: @escaping (HTTPRequestComponents) -> ID,
		interval: TimeInterval = 30,
		statusCodes: Set<HTTPResponse.Status> = [.tooManyRequests],
		methods: Set<HTTPRequest.Method>? = nil,
		maxRepeatCount: Int = 3
	) -> Self {
		httpClientMiddleware(RateLimitMiddleware(id: id, interval: interval, statusCodes: statusCodes, methods: methods, maxCount: maxRepeatCount))
	}

	/// When the rate limit is exceeded, the request will be repeated after the specified interval and all requests with the same base URL will be suspended.
	/// - Parameters:
	///  - interval: The interval to wait before repeating the request. Default to 30 seconds.
	///  - statusCodes: The set of status codes that indicate a rate limit exceeded. Default to `[429]`.
	///  - methods: The set of HTTP methods to retry. If `nil`, all methods are retried. Default to `nil`.
	///  - maxRepeatCount: The maximum number of times the request can be repeated. Default to 3.
	func waitIfRateLimitExceeded(
		interval: TimeInterval = 30,
		statusCodes: Set<HTTPResponse.Status> = [.tooManyRequests],
		methods: Set<HTTPRequest.Method>? = nil,
		maxRepeatCount: Int = 3
	) -> Self {
		waitIfRateLimitExceeded(
			id: { $0.url?.host ?? UUID().uuidString },
			interval: interval,
			statusCodes: statusCodes,
			methods: methods,
			maxRepeatCount: maxRepeatCount
		)
	}
}

private struct RateLimitMiddleware<ID: Hashable>: HTTPClientMiddleware {

	let id: (HTTPRequestComponents) -> ID
	let interval: TimeInterval
	let statusCodes: Set<HTTPResponse.Status>
	let methods: Set<HTTPRequest.Method>?
	let maxCount: Int

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		if let methods {
			guard methods.contains(request.method) else {
				return try await next(request, configs)
			}
		}
		let id = id(request)
		await waitForSynchronizedAccess(id: id, of: Void.self)
		var (res, status) = try await extractStatusCodeEvenFailed {
			try await next(request, configs)
		}
		var count: UInt = 0
		while
			statusCodes.contains(status),
			count < maxCount
		{
			count += 1
			try await withThrowingSynchronizedAccess(id: id) {
				try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
			}
			(res, status) = try await extractStatusCodeEvenFailed {
				try await next(request, configs)
			}
		}
		return try res.get()
	}
}
