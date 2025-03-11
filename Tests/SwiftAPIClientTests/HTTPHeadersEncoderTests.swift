import Foundation
import HTTPTypes
import SwiftAPIClient
import XCTest

final class HTTPHeadersEncoderTests: XCTestCase {

	func testEncoderCanEncodeDictionary() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters = ["a": "a"]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "a")])
	}

	func testEncoderCanEncodeDecimal() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let decimal: Decimal = 1.0
		let parameters = ["a": decimal]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeDecimalWithHighPrecision() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let decimal: Decimal = 1.123456
		let parameters = ["a": decimal]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1.123456")])
	}

	func testEncoderCanEncodeDouble() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters = ["a": 1.0]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1.0")])
	}

	func testEncoderCanEncodeFloat() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: Float] = ["a": 1.0]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1.0")])
	}

	func testEncoderCanEncodeInt8() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: Int8] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeInt16() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: Int16] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeInt32() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: Int32] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeInt64() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: Int64] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeUInt() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: UInt] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeUInt8() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: UInt8] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeUInt16() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: UInt16] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeUInt32() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: UInt32] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testEncoderCanEncodeUInt64() {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters: [String: UInt64] = ["a": 1]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A")!, value: "1")])
	}

	func testThatNestedDictionariesCanNotHaveBracketKeyPathsByDefault() {
		// Given
		let encoder = HTTPHeadersEncoder(nestedEncodingStrategy: .brackets)
		let parameters = ["a": ["b": "b"]]

		// Then
		XCTAssertThrowsError(try encoder.encode(parameters))
	}

	func testThatNestedDictionariesCanHaveDottedKeyPaths() {
		// Given
		let encoder = HTTPHeadersEncoder(nestedEncodingStrategy: .dots)
		let parameters = ["a": ["b": "b"]]

		// When
		let result = try? encoder.encode(parameters)

		// Then
		XCTAssertEqual(result, [HTTPField(name: HTTPField.Name("A.B")!, value: "b")])
	}

	func testThatEncodableStructCanBeEncoded() throws {
		// Given
		let encoder = HTTPHeadersEncoder()
		let parameters = EncodableStruct()

		// When
		let result = try encoder.encode(parameters)

		// Then
		let expected = [HTTPField(name: HTTPField.Name("One")!, value: "one"),
		                HTTPField(name: HTTPField.Name("Two")!, value: "2"),
		                HTTPField(name: HTTPField.Name("Three")!, value: "true"),
		                HTTPField(name: HTTPField.Name("Four")!, value: "1"),
		                HTTPField(name: HTTPField.Name("Four")!, value: "2"),
		                HTTPField(name: HTTPField.Name("Four")!, value: "3"),
		                HTTPField(name: HTTPField.Name("Five")!, value: "{\"a\":\"a\"}"),
		                HTTPField(name: HTTPField.Name("Six")!, value: "{\"a\":{\"b\":\"b\"}}"),
		                HTTPField(name: HTTPField.Name("Seven")!, value: "{\"a\":\"a\"}")]
		XCTAssertEqual(result, expected)
	}
}

private struct EncodableStruct: Encodable {
	let one = "one"
	let two = 2
	let three = true
	let four = [1, 2, 3]
	let five = ["a": "a"]
	let six = ["a": ["b": "b"]]
	let seven = NestedEncodableStruct()
}

private struct EncodableStruct1: Encodable {
	let one = "one"
	let two = 2
	let three = true
	let four = ["1", "2", "3"]
	let five = ["a": "a"]
	let six = ["a": ["b": "b"]]
	let seven = NestedEncodableStruct()
}

private struct NestedEncodableStruct: Encodable {
	let a = "a"
}

private struct OptionalEncodableStruct: Encodable {
	let one = "one"
	let two: String? = nil
}

private class EncodableSuperclass: Encodable {
	let one = "one"
	let two = 2
	let three = true
}

private final class EncodableSubclass: EncodableSuperclass {
	let four = [1, 2, 3]
	let five: OrderedDict = ["a": "a", "b": "b"]

	private enum CodingKeys: String, CodingKey {
		case four, five
	}

	override func encode(to encoder: Encoder) throws {
		try super.encode(to: encoder)

		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(four, forKey: .four)
		try container.encode(five, forKey: .five)
	}
}

private struct OrderedDict: ExpressibleByDictionaryLiteral, Encodable {

	typealias Key = String
	typealias Value = String

	let dict: [(String, String)]

	init(dictionaryLiteral elements: (String, String)...) {
		dict = elements
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: SwiftAPIClientTests.Key.self)
		for (key, value) in dict {
			try container.encode(value, forKey: .init(key))
		}
	}
}

private final class ManuallyEncodableSubclass: EncodableSuperclass {
	let four = [1, 2, 3]
	let five: OrderedDict = ["a": "a", "b": "b"]

	private enum CodingKeys: String, CodingKey {
		case four, five
	}

	/// four[]=1&four[]=2&four[]=3&five[a]=a&five[b]=b&four=one&four[five]=2&four[][four]=one
	override func encode(to encoder: Encoder) throws {
		var keyedContainer = encoder.container(keyedBy: CodingKeys.self)

		try keyedContainer.encode(four, forKey: .four)
		try keyedContainer.encode(five, forKey: .five)

		let superEncoder = keyedContainer.superEncoder()
		var superContainer = superEncoder.container(keyedBy: CodingKeys.self)
		try superContainer.encode(one, forKey: .four)

		let keyedSuperEncoder = keyedContainer.superEncoder(forKey: .four)
		var superKeyedContainer = keyedSuperEncoder.container(keyedBy: CodingKeys.self)
		try superKeyedContainer.encode(two, forKey: .five)

		var unkeyedContainer = keyedContainer.nestedUnkeyedContainer(forKey: .four)
		let unkeyedSuperEncoder = unkeyedContainer.superEncoder()
		var keyedUnkeyedSuperContainer = unkeyedSuperEncoder.container(keyedBy: CodingKeys.self)
		try keyedUnkeyedSuperContainer.encode(one, forKey: .four)
	}
}

private struct ManuallyEncodableStruct: Encodable {

	let a = ["string": "string"]
	let b = [1, 2, 3]

	private enum RootKey: String, CodingKey {
		case root
	}

	private enum TypeKeys: String, CodingKey {
		case a, b
	}

	/// root[a][string]=string&root[][]=1&root[][]=2&root[][]=3root[][a][string]=string&root[][][]=1&root[][][]=2&root[][][]=3
	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: RootKey.self)

		var nestedKeyedContainer = container.nestedContainer(keyedBy: TypeKeys.self, forKey: .root)
		try nestedKeyedContainer.encode(a, forKey: .a)

		var nestedUnkeyedContainer = container.nestedUnkeyedContainer(forKey: .root)
		try nestedUnkeyedContainer.encode(b)

		var nestedUnkeyedKeyedContainer = nestedUnkeyedContainer.nestedContainer(keyedBy: TypeKeys.self)
		try nestedUnkeyedKeyedContainer.encode(a, forKey: .a)

		var nestedUnkeyedUnkeyedContainer = nestedUnkeyedContainer.nestedUnkeyedContainer()
		try nestedUnkeyedUnkeyedContainer.encode(b)
	}
}

private struct FailingOptionalStruct: Encodable {

	enum TestedContainer {
		case keyed, unkeyed
	}

	enum CodingKeys: String, CodingKey {
		case a
	}

	let testedContainer: TestedContainer

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)

		switch testedContainer {
		case .keyed:
			var nested = container.nestedContainer(keyedBy: CodingKeys.self, forKey: .a)
			try nested.encodeNil(forKey: .a)
		case .unkeyed:
			var nested = container.nestedUnkeyedContainer(forKey: .a)
			try nested.encodeNil()
		}
	}
}

private struct TestQuery: Codable {
	var property = "property"
}

private struct Key: CodingKey {

	var stringValue: String
	var intValue: Int?

	init(stringValue: String) {
		self.stringValue = stringValue
	}

	init(_ string: String) {
		self.init(stringValue: string)
	}

	init(intValue: Int) {
		self.intValue = intValue
		stringValue = "\(intValue)"
	}
}
