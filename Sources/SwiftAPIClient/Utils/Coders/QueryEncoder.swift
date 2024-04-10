@preconcurrency import Foundation

/// Protocol defining an encoder that serializes data into a query parameters array.
public protocol QueryEncoder {

	func encode<T: Encodable>(_ value: T) throws -> [URLQueryItem]
}

public extension QueryEncoder where Self == URLQueryEncoder {

	/// A static property to get a `URLQueryEncoder` instance with default settings.
	static var urlQuery: Self { .urlQuery() }

	/// Creates and returns a `URLQueryEncoder` with customizable encoding strategies.
	/// - Parameters:
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `SecondsSince1970CodingStrategy`.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `UseDeafultKeyCodingStrategy`.
	///   - arrayEncodingStrategy: Strategy for encoding arrays. Default is `.brackets(indexed: false)`.
	///   - nestedEncodingStrategy: Strategy for encoding nested objects. Default is `.brackets`.
	///   - boolEncodingStrategy: Strategy for encoding boolean values. Default is `.literal`.
	/// - Returns: An instance of `URLQueryEncoder` configured with the specified strategies.
	static func urlQuery(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: URLQueryEncoder.ArrayEncodingStrategy = .brackets(indexed: false),
		nestedEncodingStrategy: URLQueryEncoder.NestedEncodingStrategy = .brackets,
		boolEncodingStrategy: URLQueryEncoder.BoolEncodingStrategy = .literal
	) -> Self {
		URLQueryEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			boolEncodingStrategy: boolEncodingStrategy
		)
	}
}
