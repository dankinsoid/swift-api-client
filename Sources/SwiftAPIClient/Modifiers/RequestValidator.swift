import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A struct for validating `URLRequest` instances.
public struct RequestValidator {

	/// A closure that validates a `URLRequest`.
	/// - Throws: An error if validation fails.
	public var validate: (_ request: HTTPRequest, _ body: Data?, APIClient.Configs) throws -> Void

	/// Initializes a new `RequestValidator` with a custom validation closure.
	/// - Parameter validate: A closure that takes a `URLRequest` and throws an error if validation fails.
	public init(validate: @escaping (_ request: HTTPRequest, _ body: Data?, APIClient.Configs) throws -> Void) {
		self.validate = validate
	}
}

public extension RequestValidator {

	/// A default validator that always considers the request as successful, regardless of its content.
	static var alwaysSuccess: Self {
		RequestValidator { _, _, _ in }
	}
}

public extension APIClient {

	/// Sets a custom request validator for the network client.
	/// - Parameter validator: The `RequestValidator` to be used for validating `URLRequest` instances.
	/// - Returns: An instance of `APIClient` configured with the specified request validator.
	func requestValidator(_ validator: RequestValidator) -> APIClient {
		httpClientMiddleware(RequestValidatorMiddleware(validator: validator))
	}
}

private struct RequestValidatorMiddleware: HTTPClientMiddleware {

	let validator: RequestValidator

	func execute<T>(
		request: HTTPRequest,
		body: Data?,
		configs: APIClient.Configs,
		next: (HTTPRequest, Data?, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		try validator.validate(request, body, configs)
		return try await next(request, body, configs)
	}
}
