import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// A struct for validating URL request instances.
public struct RequestValidator {

	/// A closure that validates an URL request.
	/// - Throws: An error if validation fails.
	public var validate: (_ request: HTTPRequestComponents, APIClient.Configs) throws -> Void

	/// Initializes a new `RequestValidator` with a custom validation closure.
	/// - Parameter validate: A closure that takes an URL request and throws an error if validation fails.
	public init(validate: @escaping (_ request: HTTPRequestComponents, APIClient.Configs) throws -> Void) {
		self.validate = validate
	}
}

public extension RequestValidator {

	/// A default validator that always considers the request as successful, regardless of its content.
	static var alwaysSuccess: Self {
		RequestValidator { _, _ in }
	}
}

public extension APIClient.Configs {

	/// The request validator used for validating URL request instances.
	var requestValidator: RequestValidator {
		get { self[\.requestValidator] ?? .alwaysSuccess }
		set { self[\.requestValidator] = newValue }
	}
}

public extension APIClient {

	/// Sets a custom request validator for the network client.
	/// - Parameter validator: The `RequestValidator` to be used for validating URL request instances.
	/// - Returns: An instance of `APIClient` configured with the specified request validator.
	func requestValidator(_ validator: RequestValidator) -> APIClient {
		configs { configs in
			let validate = configs.requestValidator.validate
			configs.requestValidator.validate = { request, configs in
				try validate(request, configs)
				try validator.validate(request, configs)
			}
		}
	}
}
