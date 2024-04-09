import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient.Configs {

	/// Indicates whether authentication is enabled for network requests.
	var isAuthEnabled: Bool {
		get { self[\.isAuthEnabled] ?? true }
		set { self[\.isAuthEnabled] = newValue }
	}
}

public extension APIClient {

	/// Configures the network client with a custom authentication modifier.
	/// - Parameter authModifier: An `AuthModifier` that modifies the request for authentication.
	/// - Returns: An instance of `APIClient` configured with the specified authentication modifier.
	func auth(_ authModifier: AuthModifier) -> APIClient {
		finalizeRequest { request, configs in
			if configs.isAuthEnabled {
				try authModifier.modifier(&request, configs)
			}
		}
	}

	/// Enables or disables authentication for the network client.
	/// - Parameter enabled: A Boolean value indicating whether to enable authentication.
	/// - Returns: An instance of `APIClient` with authentication set as specified.
	func auth(enabled: Bool) -> APIClient {
		configs(\.isAuthEnabled, enabled)
	}
}

/// A struct representing an authentication modifier for network requests.
public struct AuthModifier {

	/// A closure that modifies a URL request for authentication.
	public let modifier: (inout HTTPRequestComponents, APIClient.Configs) throws -> Void

	/// Initializes a new `AuthModifier` with a custom modifier closure.
	/// - Parameter modifier: A closure that modifies a URL request and `APIClient.Configs` for authentication.
	public init(modifier: @escaping (inout HTTPRequestComponents, APIClient.Configs) throws -> Void) {
		self.modifier = modifier
	}

	/// Initializes a new `AuthModifier` with a custom modifier closure.
	/// - Parameter modifier: A closure that modifies a URL request for authentication.
	public init(modifier: @escaping (inout HTTPRequestComponents) throws -> Void) {
		self.init { request, _ in
			try modifier(&request)
		}
	}

	/// Creates an authentication modifier for adding a `Authorization` header.
	public static func header(_ value: String) -> AuthModifier {
		AuthModifier {
			$0.headers[.authorization] = value
		}
	}
}

public extension AuthModifier {

	/// Creates an authentication modifier for adding a basic authentication header.
	///
	/// Basic authentication is a simple authentication scheme built into the HTTP protocol.
	/// The client sends HTTP requests with the Authorization header that contains the word Basic word followed by a space and a base64-encoded string username:password.
	/// For example, to authorize as demo / p@55w0rd the client would send
	static func basic(username: String, password: String) -> AuthModifier {
		AuthModifier {
			let field = HTTPField.authorization(username: username, password: password)
			$0.headers[field.name] = field.value
		}
	}

	/// Creates an authentication modifier for adding an API key.
	///
	/// An API key is a token that a client provides when making API calls
	static func apiKey(_ key: String, field: String = "X-API-Key") -> AuthModifier {
		AuthModifier {
			guard let name = HTTPField.Name(field) else {
				throw Errors.custom("Invalid field name: \(field)")
			}
			$0.headers[name] = key
		}
	}

	/// Creates an authentication modifier for adding a bearer token.
	///
	/// Bearer authentication (also called token authentication) is an HTTP authentication scheme that involves security tokens called bearer tokens.
	/// The name “Bearer authentication” can be understood as “give access to the bearer of this token.”
	/// The bearer token is a cryptic string, usually generated by the server in response to a login request.
	/// The client must send this token in the Authorization header when making requests to protected resources
	static func bearer(token: String) -> AuthModifier {
		AuthModifier {
			let field = HTTPField.authorization(bearerToken: token)
			$0.headers[field.name] = field.value
		}
	}
}
