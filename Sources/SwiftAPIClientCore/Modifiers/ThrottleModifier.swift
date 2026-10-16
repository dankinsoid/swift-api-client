import Foundation

public extension APIClient {

	/// Throttles equal requests to the server.
	/// - Parameters:
	///  - interval: The interval to throttle requests by.
	///
	/// If the interval is nil, then `configs.throttleInterval` is used. This allows setting the default interval for all requests via `.configs(\.throttleInterval, value)`.
	func throttle(interval: TimeInterval? = nil) -> APIClient {
		throttle(interval: interval) { $0 }
	}

	/// Throttles requests to the server by request id.
	/// - Parameters:
	///  - interval: The interval for throttling requests.
	///  - id: A closure to uniquely identify the request.
	///
	/// If the interval is nil, then `configs.throttleInterval` is used. This allows setting the default interval for all requests via `.configs(\.throttleInterval, value)`.
	func throttle<ID: Hashable>(interval: TimeInterval? = nil, id: @escaping (HTTPRequestComponents) -> ID) -> APIClient {
		configs {
			if let interval {
				$0.throttleInterval = interval
			}
		}
		.httpClientMiddleware(
			RequestsThrottleMiddleware(cache: .shared, id: id)
		)
	}
}

public extension APIClient.Configs {

	/// The interval to throttle requests by. Default is 10 seconds.
	var throttleInterval: TimeInterval {
		get { self[\.throttleInterval] ?? 10 }
		set { self[\.throttleInterval] = newValue }
	}
}

private final actor RequestsThrottlerCache {

	static let shared = RequestsThrottlerCache()
	private var responses: [AnyHashable: (Any, HTTPResponse)] = [:]

	func response<T>(for request: AnyHashable) -> (T, HTTPResponse)? {
		responses[request] as? (T, HTTPResponse)
	}

	func setResponse<T>(response: (T, HTTPResponse), for request: AnyHashable) {
		responses[request] = response
	}

	func removeResponse(for request: AnyHashable) {
		responses[request] = nil
	}
}

private struct RequestsThrottleMiddleware<ID: Hashable>: HTTPClientMiddleware {

	let cache: RequestsThrottlerCache
	let id: (HTTPRequestComponents) -> ID

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		let interval = configs.throttleInterval
		guard interval > 0 else {
			return try await next(request, configs)
		}
		let requestID = id(request)
		if let response: (T, HTTPResponse) = await cache.response(for: requestID) {
			return response
		}
		let (value, httpResponse) = try await next(request, configs)
		await cache.setResponse(response: (value, httpResponse), for: requestID)
		Task {
			try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
			await cache.removeResponse(for: requestID)
		}
		return (value, httpResponse)
	}
}
