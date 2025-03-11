import Foundation
import HTTPTypes

public struct HTTPHeadersEncoder: HeadersEncoder, ParametersEncoderOptions {

	public typealias Output = [HTTPField]
	public var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy
	public var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy
	public var arrayEncodingStrategy: ArrayEncodingStrategy
	public var nestedEncodingStrategy: NestedEncodingStrategy
	public var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
	public var boolEncodingStrategy: BoolEncodingStrategy

	public init(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		dataEncodingStrategy: JSONEncoder.DataEncodingStrategy = .base64,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .convertToTrainCase,
		arrayEncodingStrategy: ArrayEncodingStrategy = .repeatKey,
		nestedEncodingStrategy: NestedEncodingStrategy = .json(inheritKeysStrategy: false),
		boolEncodingStrategy: BoolEncodingStrategy = .literal
	) {
		self.dateEncodingStrategy = dateEncodingStrategy
		self.dataEncodingStrategy = dataEncodingStrategy
		self.arrayEncodingStrategy = arrayEncodingStrategy
		self.keyEncodingStrategy = keyEncodingStrategy
		self.boolEncodingStrategy = boolEncodingStrategy
		self.nestedEncodingStrategy = nestedEncodingStrategy
	}

	public func encode<T: Encodable>(_ value: T) throws -> [HTTPField] {
		let encoder = ParametersEncoder(path: [], context: self)
		return try getKeyedItems(from: encoder.encode(value), value: value, percentEncoded: false) {
			guard let name = HTTPField.Name($0) else {
				throw EncodingError.invalidValue($0, EncodingError.Context(codingPath: [PlainCodingKey($0)], debugDescription: "Invalid header name '\($0)'"))
			}
			return HTTPField(name: name, value: $1)
		}
	}

	public func encodeParameters<T: Encodable>(_ value: T) throws -> [String: String] {
		let items = try encode(value)
		var result: [String: String] = [:]
		for item in items {
			result[item.name.rawName] = item.value
		}
		return result
	}
}
