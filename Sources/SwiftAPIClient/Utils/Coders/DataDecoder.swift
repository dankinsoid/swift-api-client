@preconcurrency import Foundation

/// A protocol defining a decoder for deserializing `Data` into decodable types.
public protocol DataDecoder {

	func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T
}

extension JSONDecoder: DataDecoder {}
extension PropertyListDecoder: DataDecoder {}

public extension DataDecoder where Self == JSONDecoder {

	/// A static property to get a `JSONDecoder` instance with default settings.
	static var json: Self { .json() }

	/// Creates and returns a `JSONDecoder` with customizable decoding strategies.
	/// - Parameters:
	///   - dateDecodingStrategy: Strategy for decoding date values. Default is `.deferredToDate`.
	///   - dataDecodingStrategy: Strategy for decoding data values. Default is `.deferredToData`.
	///   - nonConformingFloatDecodingStrategy: Strategy for decoding non-conforming float values. Default is `.throw`.
	///   - keyDecodingStrategy: Strategy for decoding keys. Default is `.useDefaultKeys`.
	/// - Returns: An instance of `JSONDecoder` configured with the specified strategies.
	static func json(
		dateDecodingStrategy: JSONDecoder.DateDecodingStrategy = .deferredToDate,
		dataDecodingStrategy: JSONDecoder.DataDecodingStrategy = .deferredToData,
		nonConformingFloatDecodingStrategy: JSONDecoder.NonConformingFloatDecodingStrategy = .throw,
		keyDecodingStrategy: JSONDecoder.KeyDecodingStrategy = .useDefaultKeys
	) -> Self {
		let decoder = JSONDecoder()
		decoder.dataDecodingStrategy = dataDecodingStrategy
		decoder.dateDecodingStrategy = dateDecodingStrategy
		decoder.nonConformingFloatDecodingStrategy = nonConformingFloatDecodingStrategy
		decoder.keyDecodingStrategy = keyDecodingStrategy
		return decoder
	}
}
