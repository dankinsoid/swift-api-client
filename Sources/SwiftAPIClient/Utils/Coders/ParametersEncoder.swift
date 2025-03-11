import Foundation

public protocol ParametersEncoderOptions {
	var dateEncodingStrategy: JSONEncoder.DateEncodingStrategy { get }
	var keyEncodingStrategy: JSONEncoder.KeyEncodingStrategy { get }
	var dataEncodingStrategy: JSONEncoder.DataEncodingStrategy { get }
	var boolEncodingStrategy: BoolEncodingStrategy { get }
	var nestedEncodingStrategy: NestedEncodingStrategy { get }
	var arrayEncodingStrategy: ArrayEncodingStrategy { get }
}

extension ParametersEncoderOptions {

	func getKeyedItems<T>(from output: ParametersValue, value: Any, percentEncoded: Bool, item: (String, String) throws -> T) throws -> [T] {
		let array: ParametersValue.Keyed
		switch output {
		case .single, .unkeyed, .null:
			throw EncodingError.invalidValue(
				value, EncodingError.Context(codingPath: [], debugDescription: "Expected a keyed value.")
			)
		case let .keyed(dictionary):
			array = try encode(dictionary.map { (PlainCodingKey($0.0), $0.1) })
		}
		return try array.map {
			let name: String
			switch $0.0.count {
			case 0:
				throw EncodingError.invalidValue(
					value, EncodingError.Context(codingPath: $0.0, debugDescription: "No key found.")
				)
			case 1:
				name = $0.0[0].stringValue
			default:
				switch nestedEncodingStrategy {
				case .data:
					throw EncodingError.invalidValue(
						value,
						EncodingError.Context(
							codingPath: $0.0,
							debugDescription: "Nested objects are not allowed for .data nested encoding strategy."
						)
					)
				case let .flatten(block):
					name = try block($0.0)
				}
			}
			if percentEncoded {
				return try item(
					name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? name,
					$0.1.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? $0.1
				)
			} else {
				return try item(name, $0.1)
			}
		}
	}

	private func encode(_ dictionary: [(CodingKey, ParametersValue)], path: [CodingKey] = []) throws -> ParametersValue.Keyed {
		guard !dictionary.isEmpty else { return [] }
		var result: ParametersValue.Keyed = []
		for (key, query) in dictionary {
			if case .null = query {
				continue
			}
			let path = path + [key]
			switch query {
			case .null:
				break
			case let .single(value, _):
				result.append((path, value))
			case let .keyed(array):
				result += try encode(array.map { (PlainCodingKey($0.0), $0.1) }, path: path)
			case let .unkeyed(array):
				result += try encode(array, path: path)
			}
		}
		return result
	}

	private func encode(_ array: [ParametersValue], path: [CodingKey]) throws -> ParametersValue.Keyed {
		switch arrayEncodingStrategy {
		case let .keyed(convert):
			let (path, keys) = try convert(path)
			return try encode(
				array.enumerated().map {
					try (keys($0.offset), $0.element)
				},
				path: path
			)
		default:
			guard let string = try getString(from: .unkeyed(array), path: path) else {
				return []
			}
			return [(path, string)]
		}
	}

	private func getString(from output: ParametersValue, path: [CodingKey]) throws -> String? {
		switch output {
		case let .single(value, _):
			return value
		case .null:
			return nil
		case let .unkeyed(array):
			switch arrayEncodingStrategy {
			case .keyed:
				throw EncodingError.invalidValue(
					array,
					EncodingError.Context(
						codingPath: path,
						debugDescription: "Nested arrays are not allowed."
					)
				)
			case let .value(block):
				return try block(
					path,
					array.enumerated().compactMap {
						try getString(from: $0.element, path: path + [PlainCodingKey(intValue: $0.offset)])
					}
				)
			}
		case .keyed:
			if case let .data(builder, _) = nestedEncodingStrategy {
				let data = try builder(self).encode(output)
				guard let string = String(data: data, encoding: .utf8) else {
					throw EncodingError.invalidValue(
						output,
						EncodingError.Context(
							codingPath: path,
							debugDescription: "The encoded data is not a valid UTF-8 string"
						)
					)
				}
				return string
			}
			throw EncodingError.invalidValue(
				output,
				EncodingError.Context(
					codingPath: path, debugDescription: "Nested keyed objects are not allowed."
				)
			)
		}
	}
}

final class ParametersEncoder: Encoder {

	var codingPath: [CodingKey]
	let context: ParametersEncoderOptions
	var userInfo: [CodingUserInfoKey: Any]
	@Ref var result: ParametersValue

	convenience init(path: [CodingKey] = [], context: ParametersEncoderOptions) {
		var value: ParametersValue = .keyed([])
		let ref: Ref<ParametersValue> = Ref {
			value
		} set: {
			value = $0
		}
		self.init(path: path, context: context, result: ref)
	}

	init(path: [CodingKey] = [], context: ParametersEncoderOptions, result: Ref<ParametersValue>) {
		codingPath = path
		self.context = context
		userInfo = [:]
		_result = result
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
	func encode(_ value: Encodable) throws -> ParametersValue {
		let isArrayEncoder = IsArrayEncoder(codingPath: codingPath)
		try? value.encode(to: isArrayEncoder)
		let isArray = isArrayEncoder.isArray ?? false
		let isSingle = isArrayEncoder.isSingle ?? false
		if !isSingle,
		   case let .data(builder, encodeType) = context.nestedEncodingStrategy,
		   !codingPath.isEmpty,
		   !(codingPath.count < 2 && isArray && encodeType == .objects)
		{
			let data = try builder(context).encode(value)
			guard let string = String(data: data, encoding: .utf8) else {
				throw EncodingError.invalidValue(
					value,
					EncodingError.Context(
						codingPath: codingPath,
						debugDescription: "The encoded data is not a valid UTF-8 string"
					)
				)
			}
			result = .single(string, value)
		} else if let date = value as? Date {
			try context.dateEncodingStrategy.encode(date, encoder: self)
		} else if let decimal = value as? Decimal {
			result = .single(decimal.description, value)
		} else if let url = value as? URL {
			result = .single(url.absoluteString, value)
		} else if let data = value as? Data {
			try context.dataEncodingStrategy.encode(data, encoder: self)
		} else {
			try value.encode(to: self)
		}
		return result
	}
}

private struct URLQuerySingleValueEncodingContainer: SingleValueEncodingContainer,
	UnkeyedEncodingContainer
{

	var count: Int { 1 }
	let isSingle: Bool
	var codingPath: [CodingKey]
	var encoder: ParametersEncoder
	@Ref var result: ParametersValue

	mutating func encodeNil() throws {
		append(.null)
	}

	mutating func encode(_ value: Bool) throws {
		append(encoder.context.boolEncodingStrategy.encode(value), value)
	}

	mutating func encode(_ value: String) throws {
		append(value, value)
	}

	mutating func encode(_ value: Double) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: Float) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: Int) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: Int8) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: Int16) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: Int32) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: Int64) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: UInt) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: UInt8) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: UInt16) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: UInt32) throws {
		append("\(value)", value)
	}

	mutating func encode(_ value: UInt64) throws {
		append("\(value)", value)
	}

	mutating func encode<T>(_ value: T) throws where T: Encodable {
		let new = try ParametersEncoder(
			path: nestedPath(),
			context: encoder.context
		)
		.encode(value)
		append(new)
	}

	mutating func nestedContainer<NestedKey>(keyedBy _: NestedKey.Type) -> KeyedEncodingContainer<
		NestedKey
	> where NestedKey: CodingKey {
		let new: ParametersValue = .keyed([])
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
		let new = ParametersValue.unkeyed([])
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
		if isSingle {
			return ParametersEncoder(path: codingPath, context: encoder.context, result: $result)
		} else {
			let new = ParametersValue.unkeyed([])
			append(new)
			let lastIndex = result.unkeyed.count - 1
			return ParametersEncoder(
				path: nestedPath(),
				context: encoder.context,
				result: Ref { [$result] in
					$result.wrappedValue.unkeyed[lastIndex]
				} set: { [$result] newValue in
					$result.wrappedValue.unkeyed[lastIndex] = newValue
				}
			)
		}
	}

	private func nestedPath() -> [CodingKey] {
		isSingle ? codingPath : codingPath + [PlainCodingKey(intValue: count)]
	}

	func append(_ string: String, _ value: Encodable) {
		append(.single(string, value))
	}

	func append(_ value: ParametersValue) {
		if isSingle {
			result = value
		} else {
			result.unkeyed.append(value)
		}
	}
}

private struct URLQueryKeyedEncodingContainer<Key: CodingKey>: KeyedEncodingContainerProtocol {

	var codingPath: [CodingKey]
	var encoder: ParametersEncoder

	@Ref var result: [(String, ParametersValue)]

	@inline(__always)
	private func str(_ key: Key) -> String {
		encoder.context.keyEncodingStrategy.encode(key, path: codingPath)
	}

	mutating func encodeNil(forKey key: Key) throws {
		try encode("", forKey: key)
	}

	mutating func encode(_ value: Bool, forKey key: Key) throws {
		append(encoder.context.boolEncodingStrategy.encode(value), value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Bool?, forKey key: Key) throws {
		append(value.map(encoder.context.boolEncodingStrategy.encode), value, forKey: key)
	}

	mutating func encode(_ value: String, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: String?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Double, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Double?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Float, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Float?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Int, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Int8, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int8?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Int16, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int16?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Int32, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int32?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: Int64, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: Int64?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: UInt, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: UInt8, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt8?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: UInt16, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt16?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: UInt32, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt32?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encode(_ value: UInt64, forKey key: Key) throws {
		append(value.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: UInt64?, forKey key: Key) throws {
		append(value?.description, value, forKey: key)
	}

	mutating func encodeIfPresent(_ value: (some Encodable)?, forKey key: Key) throws {
		guard let value else {
			return
		}
		try encode(value, forKey: key)
	}

	mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
		let encoder = ParametersEncoder(
			path: nestedPath(for: key),
			context: encoder.context
		)
		try append(encoder.encode(value), forKey: key)
	}

	mutating func nestedContainer<NestedKey: CodingKey>(keyedBy _: NestedKey.Type, forKey key: Key)
		-> KeyedEncodingContainer<NestedKey>
	{
		let new: ParametersValue = .keyed([])
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
		let new: ParametersValue = .unkeyed([])
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
		encoder
	}

	mutating func superEncoder(forKey key: Key) -> Encoder {
		let new: ParametersValue = .unkeyed([])
		let index = result.count
		append(new, forKey: key)
		return ParametersEncoder(
			path: nestedPath(for: key),
			context: encoder.context,
			result: Ref { [$result] in
				$result.wrappedValue[index].1
			} set: { [$result] in
				$result.wrappedValue[index].1 = $0
			}
		)
	}

	private func nestedPath(for key: Key) -> [CodingKey] {
		codingPath + [key]
	}

	@inline(__always)
	private mutating func append(_ string: String?, _ value: Encodable?, forKey key: Key) {
		append(string.map { .single($0, value!) } ?? .null, forKey: key)
	}

	@inline(__always)
	private mutating func append(_ value: ParametersValue, forKey key: Key) {
		result.append((str(key), value))
	}
}

public extension CharacterSet {

	/// Creates a CharacterSet from RFC 3986 allowed characters.
	///
	/// RFC 3986 states that the following characters are "reserved" characters.
	///
	/// - General Delimiters: ":", "#", "[", "]", "@", "?", "/"
	/// - Sub-Delimiters: "!", "$", "&", "'", "(", ")", "*", "+", ",", ";", "="
	///
	/// In RFC 3986 - Section 3.4, it states that the "?" and "/" characters should not be escaped to allow
	/// query strings to include a URL. Therefore, all "reserved" characters with the exception of "?" and "/"
	/// should be percent-escaped in the query string.
	static let urlQueryAllowedRFC3986: CharacterSet = {
		let encodableDelimiters = CharacterSet(charactersIn: ":#[]@!$&'()*+,;=")
		return CharacterSet.urlQueryAllowed.subtracting(encodableDelimiters)
	}()
}

private final class IsArrayEncoder: Encoder {

	var isArray: Bool?
	var isSingle: Bool?
	var codingPath: [CodingKey] = []
	var userInfo: [CodingUserInfoKey: Any] = [:]

	init(codingPath: [CodingKey] = []) {
		self.codingPath = codingPath
	}

	func container<Key>(keyedBy type: Key.Type) -> KeyedEncodingContainer<Key> where Key: CodingKey {
		if isArray == nil {
			isArray = false
		}
		if isSingle == nil {
			isSingle = false
		}
		return KeyedEncodingContainer(MockKeyed())
	}

	func unkeyedContainer() -> UnkeyedEncodingContainer {
		if isArray == nil {
			isArray = true
		}
		if isSingle == nil {
			isSingle = false
		}
		return MockUnkeyed()
	}

	func singleValueContainer() -> SingleValueEncodingContainer {
		MockSingle(encoder: self, codingPath: codingPath)
	}

	private struct MockKeyed<Key: CodingKey>: KeyedEncodingContainerProtocol {
		var codingPath: [CodingKey] = []
		mutating func encodeNil(forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Bool, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: String, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Double, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Float, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Int, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Int8, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Int16, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Int32, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: Int64, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: UInt, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: UInt8, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: UInt16, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: UInt32, forKey key: Key) throws { throw MockError() }
		mutating func encode(_ value: UInt64, forKey key: Key) throws { throw MockError() }
		mutating func encode<T>(_ value: T, forKey key: Key) throws where T: Encodable {
			throw MockError()
		}

		mutating func nestedContainer<NestedKey: CodingKey>(
			keyedBy keyType: NestedKey.Type, forKey key: Key
		) -> KeyedEncodingContainer<NestedKey> { KeyedEncodingContainer(MockKeyed<NestedKey>()) }
		mutating func nestedUnkeyedContainer(forKey key: Key) -> any UnkeyedEncodingContainer {
			MockUnkeyed()
		}

		mutating func superEncoder() -> Encoder { IsArrayEncoder() }
		mutating func superEncoder(forKey key: Key) -> Encoder { IsArrayEncoder() }
	}

	private struct MockUnkeyed: UnkeyedEncodingContainer {

		var codingPath: [CodingKey] = []
		var count = 0

		mutating func encodeNil() throws { throw MockError() }
		mutating func encode(_ value: Bool) throws { throw MockError() }
		mutating func encode(_ value: String) throws { throw MockError() }
		mutating func encode(_ value: Double) throws { throw MockError() }
		mutating func encode(_ value: Float) throws { throw MockError() }
		mutating func encode(_ value: Int) throws { throw MockError() }
		mutating func encode(_ value: Int8) throws { throw MockError() }
		mutating func encode(_ value: Int16) throws { throw MockError() }
		mutating func encode(_ value: Int32) throws { throw MockError() }
		mutating func encode(_ value: Int64) throws { throw MockError() }
		mutating func encode(_ value: UInt) throws { throw MockError() }
		mutating func encode(_ value: UInt8) throws { throw MockError() }
		mutating func encode(_ value: UInt16) throws { throw MockError() }
		mutating func encode(_ value: UInt32) throws { throw MockError() }
		mutating func encode(_ value: UInt64) throws { throw MockError() }
		mutating func encode<T>(_ value: T) throws where T: Encodable { throw MockError() }
		mutating func nestedContainer<NestedKey: CodingKey>(keyedBy keyType: NestedKey.Type)
			-> KeyedEncodingContainer<NestedKey>
		{ KeyedEncodingContainer(MockKeyed<NestedKey>()) }
		mutating func nestedUnkeyedContainer() -> any UnkeyedEncodingContainer { MockUnkeyed() }
		mutating func superEncoder() -> Encoder { IsArrayEncoder() }
	}

	private struct MockSingle: SingleValueEncodingContainer {

		let encoder: IsArrayEncoder
		var codingPath: [CodingKey] = []

		mutating func encodeNil() throws { try throwError() }
		mutating func encode(_ value: Bool) throws { try throwError() }
		mutating func encode(_ value: String) throws { try throwError() }
		mutating func encode(_ value: Double) throws { try throwError() }
		mutating func encode(_ value: Float) throws { try throwError() }
		mutating func encode(_ value: Int) throws { try throwError() }
		mutating func encode(_ value: Int8) throws { try throwError() }
		mutating func encode(_ value: Int16) throws { try throwError() }
		mutating func encode(_ value: Int32) throws { try throwError() }
		mutating func encode(_ value: Int64) throws { try throwError() }
		mutating func encode(_ value: UInt) throws { try throwError() }
		mutating func encode(_ value: UInt8) throws { try throwError() }
		mutating func encode(_ value: UInt16) throws { try throwError() }
		mutating func encode(_ value: UInt32) throws { try throwError() }
		mutating func encode(_ value: UInt64) throws { try throwError() }
		mutating func encode<T>(_ value: T) throws where T: Encodable { try value.encode(to: encoder) }
		private func throwError() throws {
			if encoder.isArray == nil {
				encoder.isArray = false
			}
			if encoder.isSingle == nil {
				encoder.isSingle = true
			}
			throw MockError()
		}
	}
}

private struct MockError: Error {}
