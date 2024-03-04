import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Represents an HTTP method (e.g., GET, POST) in a type-safe manner.
public struct HTTPMethod: LosslessStringConvertible, RawRepresentable, Codable, Hashable, ExpressibleByStringLiteral {

	/// The raw string value of the HTTP method (e.g., "GET", "POST").
	public let rawValue: String

	/// A textual description of the HTTP method, identical to `rawValue`.
	public var description: String { rawValue }

	/// Initializes a new `HTTPMethod` with a given method name.
	public init(_ description: String) {
		rawValue = description.uppercased()
	}

	public init(rawValue: String) {
		self.init(rawValue)
	}

	public init(stringLiteral value: String) {
		self.init(value)
	}

	public init(from decoder: Decoder) throws {
		try self.init(String(from: decoder))
	}

	public func encode(to encoder: Encoder) throws {
		try rawValue.encode(to: encoder)
	}

	/// `GET`
	public static let get = HTTPMethod("GET")
	/// `PUT`
	public static let put = HTTPMethod("PUT")
	/// `POST`
	public static let post = HTTPMethod("POST")
	/// `DELETE`
	public static let delete = HTTPMethod("DELETE")
	/// `OPTIONS`
	public static let options = HTTPMethod("OPTIONS")
	/// `HEAD`
	public static let head = HTTPMethod("HEAD")
	/// `PATCH`
	public static let patch = HTTPMethod("PATCH")
	/// `TRACE`
	public static let trace = HTTPMethod("TRACE")
}

public extension URLRequest {

	/// The HTTP method of the request, represented as `HTTPMethod`.
	/// Provides a type-safe way to set and get the HTTP method of the request.
	var method: HTTPMethod? {
		get { httpMethod.map { HTTPMethod($0) } }
		set { httpMethod = newValue?.rawValue }
	}
}
