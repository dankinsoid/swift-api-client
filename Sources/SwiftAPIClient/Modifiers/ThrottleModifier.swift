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
	func throttle<ID: Hashable>(interval: TimeInterval? = nil, id: @escaping (URLRequest) -> ID) -> APIClient {
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
	private var responses: [AnyHashable: (Any, HTTPURLResponse)] = [:]

	func response<T>(for request: AnyHashable) -> (T, HTTPURLResponse)? {
		responses[request] as? (T, HTTPURLResponse)
	}

	func setResponse<T>(response: (T, HTTPURLResponse), for request: AnyHashable) {
		responses[request] = response
	}

	func removeResponse(for request: AnyHashable) {
		responses[request] = nil
	}
}

private struct RequestsThrottleMiddleware<ID: Hashable>: HTTPClientMiddleware {

	let cache: RequestsThrottlerCache
	let id: (URLRequest) -> ID

	func execute<T>(
		request: URLRequest,
		configs: APIClient.Configs,
		next: (URLRequest, APIClient.Configs) async throws -> (T, HTTPURLResponse)
	) async throws -> (T, HTTPURLResponse) {
		let interval = configs.throttleInterval
		guard interval > 0 else {
			return try await next(request, configs)
		}
		let requestID = id(request)
		if let response: (T, HTTPURLResponse) = await cache.response(for: requestID) {
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
