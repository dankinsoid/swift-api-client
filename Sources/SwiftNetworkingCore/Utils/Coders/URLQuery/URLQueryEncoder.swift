import Foundation

public struct URLQueryEncoder: QueryEncoder {

	public typealias Output = [URLQueryItem]
	public let dateEncodingStrategy: JSONEncoder.DateEncodingStrategy
	public var arrayEncodingStrategy: ArrayEncodingStrategy
	public var nestedEncodingStrategy: NestedEncodingStrategy
	public var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy
	public var trimmingSquareBrackets = true

	public init(
		dateEncodingStrategy: JSONEncoder.DateEncodingStrategy = .deferredToDate,
		keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy = .useDefaultKeys,
		arrayEncodingStrategy: ArrayEncodingStrategy = .commaSeparator,
		nestedEncodingStrategy: NestedEncodingStrategy = .point
	) {
		self.dateEncodingStrategy = dateEncodingStrategy
		self.arrayEncodingStrategy = arrayEncodingStrategy
		self.nestedEncodingStrategy = nestedEncodingStrategy
		self.keyEncodingStrategy = keyEncodingStrategy
	}

	public func encode<T: Encodable>(_ value: T, for baseURL: URL) throws -> URL {
		let items = try encode(value)
		guard !items.isEmpty else { return baseURL }
		guard var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
			throw EncodingError.invalidValue(
				baseURL,
				EncodingError.Context(codingPath: [], debugDescription: "Invalid URL components")
			)
		}
		components.queryItems = (components.queryItems ?? []) + items
		guard let baseURL = components.url else {
			throw EncodingError.invalidValue(
				baseURL,
				EncodingError.Context(codingPath: [], debugDescription: "Invalid URL components")
			)
		}
		return baseURL
	}

	public func encode<T: Encodable>(_ value: T) throws -> [URLQueryItem] {
		let encoder = _URLQueryEncoder(path: [], context: self)
		let query = try encoder.encode(value)
		return try getQueryItems(from: query)
	}

	public func encodePath<T: Encodable>(_ value: T) throws -> String {
		let items = try encode(value)
		return items.map { $0.name + QueryValue.setter + ($0.value ?? "") }.joined(separator: QueryValue.separator)
	}

	public func encodeParameters<T: Encodable>(_ value: T) throws -> [String: String] {
		let items = try encode(value)
		var result: [String: String] = [:]
		for item in items {
			result[item.name] = item.value ?? result[item.name]
		}
		return result
	}

	public enum ArrayEncodingStrategy {

		/// value1,value2
		case commaSeparator
		/// key[0]=value1&key[1]=value2
		case associative(indexed: Bool)
		case customSeparator(String)
		case custom((_ path: [CodingKey], _ string: [String]) throws -> String)
	}

	public enum NestedEncodingStrategy {

		case squareBrackets, point, json
	}

	private func getQueryItems(from output: QueryValue) throws -> [URLQueryItem] {
		let array: QueryValue.Keyed
		switch output {
		case .single, .unkeyed:
			throw QueryValue.Errors.expectedKeyedValue
		case let .keyed(dictionary):
			array = try encode(dictionary, emptyKeys: false)
		}
		return try array.map {
			let name: String
			switch nestedEncodingStrategy {
			case .squareBrackets:
				guard var key = $0.0.first else {
					throw QueryValue.Errors.unknown
				}
				let chain = $0.0.dropFirst().joined(separator: "][")
				if $0.0.count > 1 {
					key += "[" + chain + "]"
				}
				name = key
			case .point, .json:
				var result = ""
				let point = String(QueryValue.point)
				for key in $0.0 {
					if key.isEmpty {
						result += "[]"
					} else {
						if !result.isEmpty {
							result += point
						}
						result += key
					}
				}
				name = result
			}
			return URLQueryItem(name: name, value: $0.1)
		}
	}

	private func encode(_ dictionary: [(String, QueryValue)], path: [String] = [], emptyKeys: Bool) throws -> QueryValue.Keyed {
		guard !dictionary.isEmpty else { return [] }
		var result: QueryValue.Keyed = []
		for (key, query) in dictionary {
			var key = key
			if emptyKeys, Int(key) != nil {
				key = ""
			}
			let path = path + [key]
			switch query {
			case let .single(value):
				result.append((path, value))
			case let .keyed(array):
				result += try encode(array, path: path, emptyKeys: emptyKeys)
			case let .unkeyed(array):
				result += try encode(array, path: path, emptyKeys: emptyKeys)
			}
		}
		return result
	}

	private func encode(_ array: [QueryValue], path: [String], emptyKeys: Bool) throws -> QueryValue.Keyed {
		switch arrayEncodingStrategy {
		case let .associative(indexed):
			return try encode(
				array.enumerated().map { (emptyKeys ? "" : "\($0.offset)", $0.element) },
				emptyKeys: !indexed
			)
		default:
			let string = try getString(from: .unkeyed(array))
			return [(path, string)]
		}
	}

	private func getString(from output: QueryValue) throws -> String {
		switch output {
		case let .single(value):
			return value
		case let .unkeyed(array):
			switch arrayEncodingStrategy {
			case .commaSeparator:
				return try array.map(getString).joined(separator: QueryValue.comma)
			case .associative:
				throw QueryValue.Errors.prohibitedNesting
			case let .customSeparator(separator):
				return try array.map(getString).joined(separator: separator)
			case let .custom(block):
				return try block([], array.map(getString))
			}
		case .keyed:
			throw QueryValue.Errors.prohibitedNesting
		}
	}
}

final class _URLQueryEncoder: Encoder {

	var codingPath: [CodingKey]
	let context: URLQueryEncoder
	var userInfo: [CodingUserInfoKey: Any]
	var result: QueryValue

	init(path: [CodingKey] = [], context: URLQueryEncoder) {
		codingPath = path
		self.context = context
		userInfo = [:]
		result = QueryValue.keyed([])
	}

	func container<Key>(keyedBy _: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
		let container = URLQueryKeyedEncodingContainer<Key>(
			codingPath: codingPath,
			encoder: self,
			result: Ref(self, \.result.keyed)
		)
		return KeyedEncodingContainer(container)
	}

	func unkeyedContainer() -> UnkeyedEncodingContainer {
		URLQuerySingleValueEncodingContainer(
			isSingle: false,
			codingPath: codingPath,
			encoder: self,
			result: Ref(self, \.result)
		)
	}

	func singleValueContainer() -> SingleValueEncodingContainer {
		URLQuerySingleValueEncodingContainer(
			isSingle: true,
			codingPath: codingPath,
			encoder: self,
			result: Ref(self, \.result)
		)
	}

	@discardableResult
	func encode(_ value: Encodable) throws -> QueryValue {
		if context.nestedEncodingStrategy == .json, !codingPath.isEmpty {
			let jsonEncoder = JSONEncoder()
			jsonEncoder.dateEncodingStrategy = context.dateEncodingStrategy
			jsonEncoder.keyEncodingStrategy = context.keyEncodingStrategy
			let data = try jsonEncoder.encode(value)
			guard let string = String(data: data, encoding: .utf8) else {
				throw EncodingError.invalidValue(
					value,
					EncodingError.Context(
						codingPath: codingPath,
						debugDescription: "The encoded data is not a valid UTF-8 string"
					)
				)
			}
			result = .single(string)
		} else if let date = value as? Date {
			try context.dateEncodingStrategy.encode(date, encoder: self)
		} else if let decimal = value as? Decimal {
			result = .single(decimal.description)
		} else if let url = value as? URL {
			result = .single(url.absoluteString)
		} else {
			try value.encode(to: self)
		}
		return result
	}
}

private struct URLQuerySingleValueEncodingContainer: SingleValueEncodingContainer, UnkeyedEncodingContainer {

	var count: Int { 1 }
	let isSingle: Bool
	var codingPath: [CodingKey]
	var encoder: _URLQueryEncoder
	@Ref var result: QueryValue

	mutating func encodeNil() throws {
		append("")
	}

	mutating func encode(_ value: Bool) throws {
		append(value ? "true" : "false")
	}

	mutating func encode(_ value: String) throws {
		append(value)
	}

	mutating func encode(_ value: Double) throws {
		append("\(value)")
	}

	mutating func encode(_ value: Float) throws {
		append("\(value)")
	}

	mutating func encode(_ value: Int) throws {
		append("\(value)")
	}

	mutating func encode(_ value: Int8) throws {
		append("\(value)")
	}

	mutating func encode(_ value: Int16) throws {
		append("\(value)")
	}

	mutating func encode(_ value: Int32) throws {
		append("\(value)")
	}

	mutating func encode(_ value: Int64) throws {
		append("\(value)")
	}

	mutating func encode(_ value: UInt) throws {
		append("\(value)")
	}

	mutating func encode(_ value: UInt8) throws {
		append("\(value)")
	}

	mutating func encode(_ value: UInt16) throws {
		append("\(value)")
	}

	mutating func encode(_ value: UInt32) throws {
		append("\(value)")
	}

	mutating func encode(_ value: UInt64) throws {
		append("\(value)")
	}

	mutating func encode<T>(_ value: T) throws where T: Encodable {
		let new = try _URLQueryEncoder(
			path: nestedPath(),
			context: encoder.context
		)
		.encode(value)
		append(new)
	}

	mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<NestedKey> where NestedKey: CodingKey {
		let new: QueryValue = .keyed([])
		append(new)
		let lastIndex = result.unkeyed.count - 1
		let container = URLQueryKeyedEncodingContainer<NestedKey>(
			codingPath: nestedPath(),
			encoder: encoder,
			result: Ref { [$result] in
				$result.wrappedValue.unkeyed[lastIndex].keyed
			} set: { [$result] newValue in
				$result.wrappedValue.unkeyed[lastIndex].keyed = newValue
			}
		)
		return KeyedEncodingContainer(container)
	}

	mutating func nestedUnkeyedContainer() -> UnkeyedEncodingContainer {
		let new = QueryValue.unkeyed([])
		append(new)
		let lastIndex = result.unkeyed.count - 1
		return URLQuerySingleValueEncodingContainer(
			isSingle: false,
			codingPath: nestedPath(),
			encoder: encoder,
			result: Ref { [$result] in
				$result.wrappedValue.unkeyed[lastIndex]
			} set: { [$result] newValue in
				$result.wrappedValue.unkeyed[lastIndex] = newValue
			}
		)
	}

	mutating func superEncoder() -> Encoder {
		_URLQueryEncoder(path: codingPath, context: encoder.context)
	}

	private func nestedPath() -> [CodingKey] {
		isSingle ? codingPath : codingPath + [PlainCodingKey(intValue: count)]
	}

	func append(_ value: String) {
		append(.single(value))
	}

	func append(_ value: QueryValue) {
		if isSingle {
			result = value
		} else {
			result.unkeyed.append(value)
		}
	}
}

private struct URLQueryKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

	var codingPath: [CodingKey]
	var encoder: _URLQueryEncoder
	@Ref var result: [(String, QueryValue)]

	@inline(__always)
	private func str(_ key: Key) -> String {
		encoder.context.keyEncodingStrategy.encode(key, path: codingPath)
	}

	mutating func encodeNil(forKey key: Key) throws {
		try encode("", forKey: key)
	}

	mutating func encode(_ value: Bool, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: String, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Double, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Float, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Int, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Int8, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Int16, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Int32, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: Int64, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: UInt, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: UInt8, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: UInt16, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: UInt32, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encode(_ value: UInt64, forKey key: Key) throws {
		append(value.description, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
		append(value?.description ?? "", forKey: key)
	}

	mutating func encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
		guard let value else {
			append("", forKey: key)
			return
		}
		try encode(value, forKey: key)
	}

	mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
		let encoder = _URLQueryEncoder(
			path: nestedPath(for: key),
			context: encoder.context
		)
		try append(encoder.encode(value), forKey: key)
	}

	mutating func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key) -> KeyedEncodingContainer<NestedKey> {
		let new: QueryValue = .keyed([])
		let index = result.count
		append(new, forKey: key)
		let container = URLQueryKeyedEncodingContainer<NestedKey>(
			codingPath: nestedPath(for: key),
			encoder: encoder,
			result: Ref { [$result] in
				$result.wrappedValue[index].1.keyed
			} set: { [$result] in
				$result.wrappedValue[index].1.keyed = $0
			}
		)
		return KeyedEncodingContainer(container)
	}

	mutating func nestedUnkeyedContainer(forKey key: Key) -> UnkeyedEncodingContainer {
		let new: QueryValue = .unkeyed([])
		let index = result.count
		append(new, forKey: key)
		let container = URLQuerySingleValueEncodingContainer(
			isSingle: false,
			codingPath: nestedPath(for: key),
			encoder: encoder,
			result: Ref { [$result] in
				$result.wrappedValue[index].1
			} set: { [$result] in
				$result.wrappedValue[index].1 = $0
			}
		)
		return container
	}

	mutating func superEncoder() -> Encoder {
		_URLQueryEncoder(path: codingPath, context: encoder.context)
	}

	mutating func superEncoder(forKey _: Key) -> Encoder {
		_URLQueryEncoder(path: codingPath, context: encoder.context)
	}

	private func nestedPath(for key: Key) -> [CodingKey] {
		codingPath + [key]
	}

	@inline(__always)
	private mutating func append(_ value: String, forKey key: Key) {
		append(.single(value), forKey: key)
	}

	@inline(__always)
	private mutating func append(_ value: QueryValue, forKey key: Key) {
		result.append((str(key), value))
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

extension JSONEncoder.DateEncodingStrategy {

	func encode(_ date: Date, encoder: Encoder) throws {
		switch self {
		case .deferredToDate:
			try date.encode(to: encoder)
		case .secondsSince1970:
			try date.timeIntervalSince1970.encode(to: encoder)
		case .millisecondsSince1970:
			try (date.timeIntervalSince1970 * 1000).encode(to: encoder)
		case .iso8601:
			try _iso8601Formatter.string(from: date).encode(to: encoder)
		case let .formatted(formatter):
			try formatter.string(from: date).encode(to: encoder)
		case let .custom(closure):
			try closure(date, encoder)
		@unknown default:
			try date.timeIntervalSince1970.encode(to: encoder)
		}
	}
}

extension String {

	func convertToSnakeCase() -> String {
		var result = ""
		for (i, char) in enumerated() {
			if char.isUppercase {
				if i != 0 {
					result.append("_")
				}
				result.append(char.lowercased())
			} else {
				result.append(char)
			}
		}
		return result
	}
}

@available(macOS 10.12, iOS 10.0, watchOS 3.0, tvOS 10.0, *)
private let _iso8601Formatter: ISO8601DateFormatter = {
	let formatter = ISO8601DateFormatter()
	formatter.formatOptions = .withInternetDateTime
	return formatter
}()
