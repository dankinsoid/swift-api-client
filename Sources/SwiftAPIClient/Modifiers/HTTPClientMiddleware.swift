import Foundation

public protocol HTTPClientMiddleware {

//#if swift(>=6.0)
//	typealias Next<T> = @Sendable (HTTPRequestComponents, APIClient.Configs) async throws(HTTPClientMiddlewareError) -> (T, HTTPResponse)
//#else
	typealias Next<T> = @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
//#endif

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse)
}

public extension APIClient {

	/// Add a modifier to the HTTP client.
	func httpClientMiddleware(_ middleware: some HTTPClientMiddleware) -> APIClient {
		configs {
			$0.httpClientArrayMiddleware.middlewares.append(middleware)
		}
	}
}

public extension APIClient.Configs {

	var httpClientMiddleware: HTTPClientMiddleware {
		httpClientArrayMiddleware
	}
}


extension APIClient.Configs {

	var httpClientArrayMiddleware: HTTPClientArrayMiddleware {
		get { self[\.httpClientArrayMiddleware] ?? HTTPClientArrayMiddleware() }
		set { self[\.httpClientArrayMiddleware] = newValue }
	}
}

struct HTTPClientArrayMiddleware: HTTPClientMiddleware {

	typealias AnyNext<T> = @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)

	var middlewares: [HTTPClientMiddleware] = []

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping Next<T>
	) async throws -> (T, HTTPResponse) {
		var next = next
		for middleware in middlewares {
			next = { [next] in try await middleware.execute(request: $0, configs: $1, next: next) }
		}
		return try await next(request, configs)
	}

	private func wrapNext<T>(_ next: @escaping AnyNext<T>) -> Next<T> {
		{ request, configs in
			try await next(request, configs)
		}
	}
}
