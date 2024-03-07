 import Foundation

 public extension ContentEncoder where Self == FormURLEncoder {

	/// A static property to get a `FormURLEncoder` instance with default encoding strategies.
	static var formURL: Self { .formURL() }

	/// Creates and returns a `FormURLEncoder` with customizable encoding strategies.
	/// - Parameters:
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `SecondsSince1970CodingStrategy`.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `UseDeafultKeyCodingStrategy`.
	///   - arrayEncodingStrategy: Strategy for encoding arrays. Default is `.commaSeparator`.
	///   - nestedEncodingStrategy: Strategy for encoding nested objects. Default is `.point`.
	///   - trimmingSquareBrackets: A flag to determine if square brackets should be trimmed. Default is `true`.
	/// - Returns: An instance of `Self` configured with the specified strategies.
	static func formURL(
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: URLQueryEncoder.ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: URLQueryEncoder.NestedEncodingStrategy = .point,
		trimmingSquareBrackets: Bool = true
	) -> Self {
		FormURLEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			trimmingSquareBrackets: trimmingSquareBrackets
		)
	}
 }

/// A `ContentEncoder` for encoding objects into `x-www-form-urlencoded` format.
 public struct FormURLEncoder: ContentEncoder {

	private var urlEncoder: URLQueryEncoder

	/// Initializes a new `FormURLEncoder` with the specified encoding strategies.
	/// - Parameters:
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `SecondsSince1970CodingStrategy`.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `UseDeafultKeyCodingStrategy`.
	///   - arrayEncodingStrategy: Strategy for encoding arrays. Default is `.commaSeparator`.
	///   - nestedEncodingStrategy: Strategy for encoding nested objects. Default is `.point`.
	///   - trimmingSquareBrackets: A flag to determine if square brackets should be trimmed. Default is `true`.
	public init(
        dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
        keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
        arrayEncodingStrategy: URLQueryEncoder.ArrayEncodingStrategy = .commaSeparator,
        nestedEncodingStrategy: URLQueryEncoder.NestedEncodingStrategy = .point,
		trimmingSquareBrackets: Bool = true
	) {
		urlEncoder = URLQueryEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy
		)
		urlEncoder.trimmingSquareBrackets = trimmingSquareBrackets
	}

	/// The content type associated with this encoder, which is `application/x-www-form-urlencoded`.
	public var contentType: ContentType {
		.application(.urlEncoded)
	}

	/// Encodes the given `Encodable` value into `x-www-form-urlencoded` format.
	/// - Parameter value: The `Encodable` value to encode.
	/// - Throws: An `Error` if encoding fails.
	/// - Returns: The encoded data as `Data`.
	public func encode(_ value: some Encodable) throws -> Data {
		guard let data = try urlEncoder.encodePath(value).data(using: .utf8) else { throw Errors.unknown }
		return data
	}
 }
