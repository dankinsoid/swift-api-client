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

struct HTTPClientMiddlewareError: Error {

	public let underlying: Error
	private var values: [PartialKeyPath<Self>: Any] = [:]

	public init(_ underlying: Error) {
		self.underlying = underlying
	}

	public init(_ underlying: String) {
		self.underlying = Errors.custom(underlying)
	}

	public subscript<T>(_ keyPath: WritableKeyPath<Self, T>) -> T? {
		get {
			values[keyPath] as? T
		}
		set {
			values[keyPath] = newValue
		}
	}

	public subscript<T>(_ keyPath: WritableKeyPath<Self, T?>) -> T? {
		get {
			values[keyPath] as? T
		}
		set {
			values[keyPath] = newValue
		}
	}

	public func with<T>(_ keyPath: WritableKeyPath<Self, T>, _ value: T) -> HTTPClientMiddlewareError {
		var result = self
		result[keyPath: keyPath] = value
		return result
	}
}

extension HTTPClientMiddlewareError {

	var response: HTTPResponse? {
		get { self[\.response] }
		set { self[\.response] = newValue }
	}
}

private extension APIClient.Configs {

	var httpClientArrayMiddleware: HTTPClientArrayMiddleware {
		get { self[\.httpClientArrayMiddleware] ?? HTTPClientArrayMiddleware() }
		set { self[\.httpClientArrayMiddleware] = newValue }
	}
}

private struct HTTPClientArrayMiddleware: HTTPClientMiddleware {

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
			do {
				return try await next(request, configs)
			} catch let error as HTTPClientMiddlewareError {
				throw error
			} catch {
				throw HTTPClientMiddlewareError(error)
			}
		}
	}
}
