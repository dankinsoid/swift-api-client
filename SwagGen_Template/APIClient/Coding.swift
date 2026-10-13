import Foundation
import SwiftAPIClient

public typealias APIModel = Codable & Equatable

public typealias DateTime = Date
public typealias File = Data
public typealias ID = UUID

extension Encodable {

	func encode() -> String {
		(self as? String) ?? "\(self)"
	}
}

/// A free-form value: the `anyType` the template emits for schemas without a type.
public enum JSON: Codable, Equatable, Sendable {

	case null
	case bool(Bool)
	case number(Decimal)
	case string(String)
	case array([JSON])
	case object([String: JSON])

	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		// Bool first, so that `true` never decodes as a number.
		if container.decodeNil() {
			self = .null
		} else if let value = try? container.decode(Bool.self) {
			self = .bool(value)
		} else if let value = try? container.decode(Decimal.self) {
			self = .number(value)
		} else if let value = try? container.decode(String.self) {
			self = .string(value)
		} else if let value = try? container.decode([JSON].self) {
			self = .array(value)
		} else {
			self = .object(try container.decode([String: JSON].self))
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
		case .null: try container.encodeNil()
		case .bool(let value): try container.encode(value)
		case .number(let value): try container.encode(value)
		case .string(let value): try container.encode(value)
		case .array(let value): try container.encode(value)
		case .object(let value): try container.encode(value)
		}
	}
}

// `type: string, format: decimal` fields travel as JSON strings and surface as `Decimal`.
enum DecimalCoding {

	private static let locale = Locale(identifier: "en_US_POSIX")

	static func decode(_ string: String, codingPath: [CodingKey]) throws -> Decimal {
		// `Decimal(string:)` accepts a numeric prefix and ignores the rest, so validate the whole string first.
		guard
			string.range(of: #"^[+-]?[0-9]+(\.[0-9]+)?$"#, options: .regularExpression) != nil,
			let value = Decimal(string: string, locale: locale)
		else {
			throw DecodingError.dataCorrupted(
				DecodingError.Context(codingPath: codingPath, debugDescription: "Invalid decimal string \"\(string)\"")
			)
		}
		return value
	}

	static func encode(_ value: Decimal) -> String {
		var value = value
		return NSDecimalString(&value, locale)
	}
}

extension KeyedDecodingContainer {

	func decodeDecimal(forKey key: Key) throws -> Decimal {
		try DecimalCoding.decode(decode(String.self, forKey: key), codingPath: codingPath + [key])
	}

	func decodeDecimalIfPresent(forKey key: Key) throws -> Decimal? {
		try decodeIfPresent(String.self, forKey: key).map {
			try DecimalCoding.decode($0, codingPath: codingPath + [key])
		}
	}
}

extension KeyedEncodingContainer {

	mutating func encodeDecimal(_ value: Decimal, forKey key: Key) throws {
		try encode(DecimalCoding.encode(value), forKey: key)
	}

	mutating func encodeDecimalIfPresent(_ value: Decimal?, forKey key: Key) throws {
		try encodeIfPresent(value.map(DecimalCoding.encode), forKey: key)
	}
}

extension KeyedDecodingContainer where Key == PlainCodingKey {

	/// Decodes the value at a dotted discriminator path, e.g. `meta.type`.
	func decode<T: Decodable>(path: [PlainCodingKey]) throws -> T {
		guard let key = path.first else {
			throw DecodingError.dataCorrupted(
				DecodingError.Context(codingPath: codingPath, debugDescription: "Empty coding path")
			)
		}
		if path.count == 1 {
			return try decode(T.self, forKey: key)
		}
		return try nestedContainer(keyedBy: PlainCodingKey.self, forKey: key).decode(path: Array(path.dropFirst()))
	}
}
