import Foundation

public extension ContentEncoder where Self == FormURLEncoder {

	/// A static property to get a `FormURLEncoder` instance with default encoding strategies.
	static var formURL: Self { .formURL() }

	/// Creates and returns a `FormURLEncoder` with customizable encoding strategies.
	/// - Parameters:
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `.secondsSince1970`.
	///   - dataEncodingStrategy: Strategy for encoding data values. Default is `.base64.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `.useDeafultKeys`.
	///   - arrayEncodingStrategy: Strategy for encoding arrays. Default is `.commaSeparator`.
	///   - nestedEncodingStrategy: Strategy for encoding nested objects. Default is `.brackets`.
	///   - boolEncodingStrategy: Strategy for encoding boolean values. Default is `.literal`.
	/// - Returns: An instance of `Self` configured with the specified strategies.
	static func formURL(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: NestedEncodingStrategy = .brackets,
		boolEncodingStrategy: BoolEncodingStrategy = .literal
	) -> Self {
		FormURLEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			dataEncodingStrategy: dataEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			boolEncodingStrategy: boolEncodingStrategy
		)
	}
}

/// A `ContentEncoder` for encoding objects into `x-www-form-urlencoded` format.
public struct FormURLEncoder: ContentEncoder {

	private var urlEncoder: URLQueryEncoder

	/// Initializes a new `FormURLEncoder` with the specified encoding strategies.
	/// - Parameters:
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `.secondsSince1970`.
	///   - dataEncodingStrategy: Strategy for encoding data values. Default is `.base64.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `.useDeafultKeys`.
	///   - arrayEncodingStrategy: Strategy for encoding arrays. Default is `.commaSeparator`.
	///   - nestedEncodingStrategy: Strategy for encoding nested objects. Default is `.brackets`.
	///   - boolEncodingStrategy: Strategy for encoding boolean values. Default is `.literal`.
	public init(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: NestedEncodingStrategy = .brackets,
		boolEncodingStrategy: BoolEncodingStrategy = .literal
	) {
		urlEncoder = URLQueryEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			dataEncodingStrategy: dataEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			boolEncodingStrategy: boolEncodingStrategy
		)
	}

	/// The content type associated with this encoder, which is `application/x-www-form-urlencoded; charset=utf-8`.
	public var contentType: ContentType {
		.application(.urlEncoded).charset(.utf8)
	}

	/// Encodes the given `Encodable` value into `x-www-form-urlencoded` format.
	/// - Parameter value: The `Encodable` value to encode.
	/// - Throws: An `Error` if encoding fails.
	/// - Returns: The encoded data as `Data`.
	public func encode(_ value: some Encodable) throws -> Data {
		guard let data = try urlEncoder.encodeQuery(value).data(using: .utf8) else { throw Errors.unknown }
		return data
	}
}
