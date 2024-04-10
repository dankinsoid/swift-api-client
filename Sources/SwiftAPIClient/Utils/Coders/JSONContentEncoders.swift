@preconcurrency import Foundation

public extension ContentEncoder where Self == JSONEncoder {

	/// A static property to get a `JSONEncoder` instance with default settings.
	static var json: Self { .json() }

	/// Creates and returns a `JSONEncoder` with customizable encoding strategies.
	/// - Parameters:
	///   - outputFormatting: The formatting of the output JSON data. Default is `.sortedKeys`.
	///   - dataEncodingStrategy: Strategy for encoding data values. Default is `.deferredToData`.
	///   - dateEncodingStrategy: Strategy for encoding date values. Default is `.deferredToDate`.
	///   - keyEncodingStrategy: Strategy for encoding key names. Default is `.useDefaultKeys`.
	///   - nonConformingFloatEncodingStrategy: Strategy for encoding non-conforming float values. Default is `.throw`.
	/// - Returns: An instance of `JSONEncoder` configured with the specified strategies.
	static func json(
		outputFormatting: JSONEncoder.OutputFormatting = .sortedKeys,
		dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .deferredToData,
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		nonConformingFloatEncodingStrategy: JSONEncoder.NonConformingFloatEncodingStrategy = .throw
	) -> Self {
		let encoder = JSONEncoder()
		encoder.outputFormatting = outputFormatting
		encoder.dateEncodingStrategy = dateEncodingStrategy
		encoder.keyEncodingStrategy = keyEncodingStrategy
		encoder.dataEncodingStrategy = dataEncodingStrategy
		encoder.nonConformingFloatEncodingStrategy = nonConformingFloatEncodingStrategy
		return encoder
	}
}

extension JSONEncoder: ContentEncoder {

	/// The content type associated with this encoder, which is `application/json`.
	public var contentType: ContentType {
		.application(.json)
	}
}
