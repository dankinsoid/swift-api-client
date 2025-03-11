import Foundation
import HTTPTypes

/// Protocol defining an encoder that serializes data into HTTP headers.
public protocol HeadersEncoder {

	func encode<T: Encodable>(_ value: T) throws -> [HTTPField]
}

public extension HeadersEncoder where Self == HTTPHeadersEncoder {

	/// A static property to get a `HTTPHeadersEncoder` instance with default settings.
	static var `default`: Self { .default() }

	/// Creates and returns a `HTTPHeadersEncoder` with customizable encoding strategies.
	/// - Parameters:
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `.secondsSince1970`.
	///   - dataEncodingStrategy: Strategy for encoding data values. Default is `.base64.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `.convertToTrainCase`.
	///   - arrayEncodingStrategy: Strategy for encoding arrays. Default is `.repeatKey`.
	///   - nestedEncodingStrategy: Strategy for encoding nested objects. Default is `.json`.
	///   - boolEncodingStrategy: Strategy for encoding boolean values. Default is `.literal`.
	/// - Returns: An instance of `HTTPHeadersEncoder` configured with the specified strategies.
	static func `default`(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToTrainCase,
		arrayEncodingStrategy: ArrayEncodingStrategy = .repeatKey,
		nestedEncodingStrategy: NestedEncodingStrategy = .json(inheritKeysStrategy: false),
		boolEncodingStrategy: BoolEncodingStrategy = .literal
	) -> Self {
		HTTPHeadersEncoder(
			dateEncodingStrategy: dateEncodingStrategy,
			dataEncodingStrategy: dataEncodingStrategy,
			keyEncodingStrategy: keyEncodingStrategy,
			arrayEncodingStrategy: arrayEncodingStrategy,
			nestedEncodingStrategy: nestedEncodingStrategy,
			boolEncodingStrategy: boolEncodingStrategy
		)
	}
}
