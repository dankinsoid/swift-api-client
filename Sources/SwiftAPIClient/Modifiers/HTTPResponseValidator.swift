import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes

/// A struct for validating HTTP responses.
public struct HTTPResponseValidator {

	/// A closure that validates an `HTTPURLResponse` and associated `Data` and the current network client configs.
	/// - Throws: An error if validation fails.
	public var validate: (HTTPResponse, Data, APIClient.Configs) throws -> Void

	/// Initializes a new `HTTPResponseValidator` with a custom validation closure.
	/// - Parameter validate: A closure that takes an `HTTPURLResponse` and `Data` and the current network client configs, and throws an error if validation fails.
	public init(_ validate: @escaping (HTTPResponse, Data, APIClient.Configs) throws -> Void) {
		self.validate = validate
	}
}

public extension HTTPResponseValidator {

	/// A default validator that checks if the status code is within the given range.
	/// Defaults to the range 200...299.
	static var statusCode: Self {
		statusCode(.successful)
	}

	/// Creates a validator to check if the status code is within a specific range.
	/// - Parameter codes: The range of acceptable status codes.
	/// - Returns: An `HTTPResponseValidator` that validates based on the specified status code range.
	static func statusCode(_ codes: ClosedRange<Int>) -> Self {
		HTTPResponseValidator { response, _, configs in
			guard codes.contains(response.status.code) || configs.ignoreStatusCodeValidator else {
				throw InvalidStatusCode(response.status)
			}
		}
	}

	/// Creates a validator to check if the status is of a specific kind.
	/// - Parameter kind: The kind of acceptable status.
	/// - Returns: An `HTTPResponseValidator` that validates based on the specified status kind.
	static func statusCode(_ kind: HTTPResponse.Status.Kind) -> Self {
		HTTPResponseValidator { response, _, configs in
			guard response.status.kind == kind || configs.ignoreStatusCodeValidator else {
				throw InvalidStatusCode(response.status)
			}
		}
	}
}

public struct InvalidStatusCode: Error, LocalizedError, CustomStringConvertible {

    /// The invalid status code.
    public let status: HTTPResponse.Status

    public init(_ status: HTTPResponse.Status) {
        self.status = status
    }

    public var errorDescription: String? { description }
    public var description: String {
        "Invalid status code: \(status.code) \(status.reasonPhrase)"
    }
}

public extension HTTPResponseValidator {

	/// A validator that always considers the response as successful.
	static var alwaysSuccess: Self {
		HTTPResponseValidator { _, _, _ in }
	}
}

public extension APIClient.Configs {

	/// The HTTP response validator used for validating network responses.
	/// Gets the currently set `HTTPResponseValidator`, or `.alwaysSuccess` if not set.
	/// Sets a new `HTTPResponseValidator`.
	var httpResponseValidator: HTTPResponseValidator {
		get { self[\.httpResponseValidator] ?? .alwaysSuccess }
		set { self[\.httpResponseValidator] = newValue }
	}
}

public extension APIClient {

	/// Sets a custom HTTP response validator for the network client.
	/// - Parameter validator: The `HTTPResponseValidator` to be used for validating responses.
	/// - Returns: An instance of `APIClient` configured with the specified HTTP response validator.
	func httpResponseValidator(_ validator: HTTPResponseValidator) -> APIClient {
		configs {
			let oldValidator = $0.httpResponseValidator.validate
			$0.httpResponseValidator = HTTPResponseValidator {
				try oldValidator($0, $1, $2)
				try validator.validate($0, $1, $2)
			}
		}
	}
}

public extension APIClient.Configs {

	var ignoreStatusCodeValidator: Bool {
		get { self[\.ignoreStatusCodeValidator] ?? false }
		set { self[\.ignoreStatusCodeValidator] = newValue }
	}
}

func extractStatusCodeEvenFailed<T>(_ request: () async throws -> (T, HTTPResponse)) async throws -> (Result<(T, HTTPResponse), Error>, HTTPResponse.Status) {
	let status: HTTPResponse.Status
	let result: Result<(T, HTTPResponse), Error>
	do {
		let value = try await request()
		status = value.1.status
		result = .success(value)
	} catch let error as InvalidStatusCode {
		status = error.status
		result = .failure(error)
	} catch let error as APIClientError {
		if let code = error.context.status {
			status = code
			result = .failure(error)
		} else {
			throw error
		}
	} catch {
		throw error
	}
	return (result, status)
}
