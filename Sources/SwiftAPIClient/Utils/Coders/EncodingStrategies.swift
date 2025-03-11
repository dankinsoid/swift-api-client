import Foundation

public enum ArrayEncodingStrategy {

	case keyed((_ path: [CodingKey]) throws -> (path: [CodingKey], items: (Int) throws -> CodingKey))
	case value((_ path: [CodingKey], _ values: [String]) throws -> String)

	/// value1,value2
	public static var commaSeparator: Self {
		.separator(",")
	}

	@available(*, deprecated, renamed: "value")
	public static func custom(_ encode: @escaping (_ path: [CodingKey], _ string: [String]) throws -> String) -> Self {
		.value(encode)
	}

	/// key[0]=value1&key[1]=value2
	public static func brackets(indexed: Bool = true) -> Self {
		.keyed { path in
			(path,
			 { PlainCodingKey(stringValue: indexed ? "\($0)" : "", intValue: $0) })
		}
	}

	/// No brackets are appended. The key is encoded as is and repeated for each value.
	public static let repeatKey = ArrayEncodingStrategy.keyed { path in
		guard let key = path.last else {
			throw EncodingError.invalidValue(
				[],
				EncodingError.Context(codingPath: path, debugDescription: "No key found.")
			)
		}
		return (Array(path.dropFirst()), { _ in key })
	}

	/// value1,value2
	public static func separator(_ separator: String) -> Self {
		.value { path, values in
			guard path.last?.intValue == nil else {
				throw EncodingError.invalidValue(
					values,
					EncodingError.Context(
						codingPath: path,
						debugDescription: "Nested arrays are not allowed for .separator(\(separator)) array encoding strategy."
					)
				)
			}
			return values.joined(separator: separator)
		}
	}
}

public struct BoolEncodingStrategy {

	public let encode: (Bool) -> String

	public init(_ encode: @escaping (Bool) -> String) {
		self.encode = encode
	}

	public static let numeric: Self = .init { $0 ? "1" : "0" }
	public static let literal: Self = .init(\.description)
}

public enum NestedEncodingStrategy {

	case data(encoder: (ParametersEncoderOptions) -> DataEncoder, type: ValueType)
	case flatten(([CodingKey]) throws -> String)

	public static func json(_ encoder: JSONEncoder, encode: ValueType = .objects) -> NestedEncodingStrategy {
		.data(encoder: { _ in encoder }, type: encode)
	}

	public static func json(inheritKeysStrategy: Bool = true, encode: ValueType = .objects) -> NestedEncodingStrategy {
		.data(
			encoder: { options in
				let encoder = JSONEncoder()
				encoder.dateEncodingStrategy = options.dateEncodingStrategy
				encoder.dataEncodingStrategy = options.dataEncodingStrategy
				if inheritKeysStrategy {
					encoder.keyEncodingStrategy = options.keyEncodingStrategy
				}
				return encoder
			},
			type: encode
		)
	}

	public static let json: NestedEncodingStrategy = .json()

	public static let brackets: NestedEncodingStrategy = .flatten { path in
		var key = path[0].stringValue
		let chain = path.dropFirst().map(\.stringValue).joined(separator: "][")
		if path.count > 1 {
			key += "[" + chain + "]"
		}
		return key
	}

	public static let dots: NestedEncodingStrategy = .flatten { path in
		var result = ""
		let point = String(ParametersValue.point)
		var wasInt = false
		for key in path {
			if key.intValue != nil || wasInt || key.stringValue.isEmpty {
				result += "[\(key.stringValue)]"
				wasInt = true
			} else {
				if !result.isEmpty, result.last != "]" {
					result += point
				}
				result += key.stringValue
			}
		}
		return result
	}

	public enum ValueType {
		case objects, arraysAndObjects
	}
}

public extension JSONEncoder.KeyEncodingStrategy {

	/// Converts the key to Train-Case.
	static let convertToTrainCase: Self = .custom { keys in
		guard !keys.isEmpty else { return PlainCodingKey("") }
		return PlainCodingKey(keys[keys.count - 1].stringValue.convertToCase { $0.map(\.capitalized).joined(separator: "-") })
	}

	/// Converts the key to kebab-case.
	static let convertToKebabCase: Self = .custom { keys in
		guard !keys.isEmpty else { return PlainCodingKey("") }
		return PlainCodingKey(keys[keys.count - 1].stringValue.convertToCase { $0.map(\.lowercasedFirstLetter).joined(separator: "-") })
	}
}

extension JSONEncoder.DateEncodingStrategy {

	func encode(_ date: Date, encoder: Encoder) throws {
		#if os(Linux) && swift(>=5.10)
		let jsonEncoder = JSONEncoder()
		jsonEncoder.dateEncodingStrategy = self

		/// Encode the date using the current encoding strategy
		let encodedData = try jsonEncoder.encode(date)

		/// Decode as CustomDate (String or Number)
		let value = try JSONDecoder().decode(CustomDate.self, from: encodedData)
		if let string = value.string {
			try string.encode(to: encoder)
		} else if let number = value.number {
			try number.encode(to: encoder)
		} else {
			throw EncodingError.invalidValue(
				value,
				EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Invalid date encoding.")
			)
		}
		#else
		switch self {
		case .deferredToDate:
			try date.encode(to: encoder)
		case .millisecondsSince1970:
			try (date.timeIntervalSince1970 * 1000).encode(to: encoder)
		case .secondsSince1970:
			try date.timeIntervalSince1970.encode(to: encoder)
		case .iso8601:
			try _iso8601Formatter.string(from: date).encode(to: encoder)
		case let .formatted(formatter):
			try formatter.string(from: date).encode(to: encoder)
		case let .custom(closure):
			try closure(date, encoder)
		@unknown default:
			try date.encode(to: encoder)
		}
		#endif
	}
}

private struct CustomDate: Decodable {

	var string: String?
	var number: Double?

	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		if let string = try? container.decode(String.self) {
			self.string = string
		} else if let number = try? container.decode(Double.self) {
			self.number = number
		}
	}
}

extension JSONEncoder.DataEncodingStrategy {

	func encode(_ data: Data, encoder: Encoder) throws {
		switch self {
		case .deferredToData:
			try data.encode(to: encoder)
		case .base64:
			try data.base64EncodedString().encode(to: encoder)
		case let .custom(closure):
			try closure(data, encoder)
		@unknown default:
			try data.base64EncodedString().encode(to: encoder)
		}
	}
}

extension JSONEncoder.KeyEncodingStrategy {

	func encode(_ key: CodingKey, path: [CodingKey]) -> String {
		switch self {
		case .useDefaultKeys:
			return key.stringValue
		case .convertToSnakeCase:
			return key.stringValue.convertToSnakeCase()
		case let .custom(closure):
			return closure(path + [key]).stringValue
		@unknown default:
			return key.stringValue
		}
	}
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private let _iso8601Formatter: ISO8601DateFormatter = {
	let formatter = ISO8601DateFormatter()
	formatter.formatOptions = .withInternetDateTime
	return formatter
}()
