import Foundation
import SwiftAPIClient
import XCTest

final class URLEncodedFormQueryEncoderTests: XCTestCase {

	func testThatQueryIsBodyEncodedAndProperContentTypeIsSetForPOSTRequest() throws {
		// Given
		var client = APIClient.test.bodyEncoder(.formURL)

		// When
		client = client.body(TestQuery())

		// Then
		let request = try client.request()
        let body = try client.request().body?.data
		XCTAssertEqual(request.headers[.contentType], "application/x-www-form-urlencoded; charset=utf-8")
		XCTAssertEqual(body, Data("property=property".utf8))
	}

	func testThatQueryIsBodyEncodedButContentTypeIsNotSetWhenRequestAlreadyHasContentType() throws {
		// Given
		var client = APIClient.test.header(.contentType, "type").bodyEncoder(.formURL)

		// When
		client = client.body(TestQuery())

		// Then
		let request = try client.request()
		XCTAssertEqual(request.headers[.contentType], "type")
        XCTAssertEqual(request.body?.data, Data("property=property".utf8))
	}
}

final class FormURLEncoderTests: XCTestCase {

	func testEncoderCanEncodeDictionary() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["a": "a"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=a")
	}

	func testEncoderCanEncodeDecimal() {
		// Given
		let encoder = FormURLEncoder()
		let decimal: Decimal = 1.0
		let parameters = ["a": decimal]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeDecimalWithHighPrecision() {
		// Given
		let encoder = FormURLEncoder()
		let decimal: Decimal = 1.123456
		let parameters = ["a": decimal]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1.123456")
	}

	func testEncoderCanEncodeDouble() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["a": 1.0]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1.0")
	}

	func testEncoderCanEncodeFloat() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: Float] = ["a": 1.0]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1.0")
	}

	func testEncoderCanEncodeInt8() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: Int8] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeInt16() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: Int16] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeInt32() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: Int32] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeInt64() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: Int64] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeUInt() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: UInt] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeUInt8() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: UInt8] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeUInt16() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: UInt16] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeUInt32() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: UInt32] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testEncoderCanEncodeUInt64() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: UInt64] = ["a": 1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a=1")
	}

	func testThatNestedDictionariesCanHaveBracketKeyPathsByDefault() {
		// Given
		let encoder = FormURLEncoder(nestedEncodingStrategy: .brackets)
		let parameters = ["a": ["b": "b"]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a%5Bb%5D=b")
	}

	func testThatNestedDictionariesCanHaveExplicitBracketKeyPaths() {
		// Given
		let encoder = FormURLEncoder(nestedEncodingStrategy: .brackets)
		let parameters = ["a": ["b": "b"]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a%5Bb%5D=b")
	}

	func testThatNestedDictionariesCanHaveDottedKeyPaths() {
		// Given
		let encoder = FormURLEncoder(nestedEncodingStrategy: .dots)
		let parameters = ["a": ["b": "b"]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "a.b=b")
	}

	//    func testThatNestedDictionariesCanHaveCustomKeyPaths() {
	//        // Given
	//        let encoder = FormURLEncoder(nestedEncodingStrategy: .init { "-\($0)" })
	//        let parameters = ["a": ["b": "b"]]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "a-b=b")
	//    }

	func testThatEncodableStructCanBeEncoded() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = EncodableStruct()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "one=one&two=2&three=true&four=1%2C2%2C3&five%5Ba%5D=a&six%5Ba%5D%5Bb%5D=b&seven%5Ba%5D=a"
		XCTAssertEqual(result, expected)
	}

	func testThatManuallyEncodableStructCanBeEncoded() {
		// Given
        let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: false))
		let parameters = ManuallyEncodableStruct()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		// root[a][string]=string&root[][]=1&root[][]=2&root[][]=3root[][a][string]=string&root[][][]=1&root[][][]=2&root[][][]=3
		let expected = "root%5Ba%5D%5Bstring%5D=string&root%5B%5D%5B%5D=1&root%5B%5D%5B%5D=2&root%5B%5D%5B%5D=3&root%5B%5D%5Ba%5D%5Bstring%5D=string&root%5B%5D%5B%5D%5B%5D=1&root%5B%5D%5B%5D%5B%5D=2&root%5B%5D%5B%5D%5B%5D=3"
		XCTAssertEqual(result, expected)
	}

	func testThatEncodableClassWithNoInheritanceCanBeEncoded() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = EncodableSuperclass()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "one=one&two=2&three=true")
	}

	func testThatEncodableSubclassCanBeEncoded() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = EncodableSubclass()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "one=one&two=2&three=true&four=1%2C2%2C3&five%5Ba%5D=a&five%5Bb%5D=b"
		XCTAssertEqual(result, expected)
	}

	func testThatManuallyEncodableSubclassCanBeEncoded() {
		// Given
        let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: false))
		let parameters = ManuallyEncodableSubclass()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "four%5B%5D=1&four%5B%5D=2&four%5B%5D=3&five%5Ba%5D=a&five%5Bb%5D=b&four=one&four%5Bfive%5D=2&four%5B%5D%5Bfour%5D=one"
		XCTAssertEqual(result, expected)
	}

	func testThatARootArrayCannotBeEncoded() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = [1]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertFalse(result != nil)
	}

	func testThatARootValueCannotBeEncoded() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = "string"

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertFalse(result != nil)
	}

	func testThatEncodableSuperclassCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = ["foo": [EncodableSuperclass()]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "foo%5B0%5D%5Bone%5D=one&foo%5B0%5D%5Btwo%5D=2&foo%5B0%5D%5Bthree%5D=true")
	}

	func testThatEncodableSuperclassCanBeEncodedWithIndexInBracketsAndNestedDots() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true), nestedEncodingStrategy: .dots)
		let parameters = ["foo": [EncodableSuperclass()]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "foo%5B0%5D%5Bone%5D=one&foo%5B0%5D%5Btwo%5D=2&foo%5B0%5D%5Bthree%5D=true"
		XCTAssertEqual(result, expected)
	}

	func testThatEncodableSubclassCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = EncodableSubclass()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "one=one&two=2&three=true&four%5B0%5D=1&four%5B1%5D=2&four%5B2%5D=3&five%5Ba%5D=a&five%5Bb%5D=b"
		// four[0]=1&four[1]=2&four[2]=3&five[a]=a&five[b]=b&four=one&four[five]=2&four[0][four]=one
		XCTAssertEqual(result, expected)
	}

	func testThatManuallyEncodableSubclassCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = ManuallyEncodableSubclass()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "four%5B0%5D=1&four%5B1%5D=2&four%5B2%5D=3&five%5Ba%5D=a&five%5Bb%5D=b&four=one&four%5Bfive%5D=2&four%5B0%5D%5Bfour%5D=one"
		XCTAssertEqual(result, expected)
	}

	func testThatEncodableStructCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = EncodableStruct()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "one=one&two=2&three=true&four%5B0%5D=1&four%5B1%5D=2&four%5B2%5D=3&five%5Ba%5D=a&six%5Ba%5D%5Bb%5D=b&seven%5Ba%5D=a"
		XCTAssertEqual(result, expected)
	}

    func testThatEncodableStructCanBeEncodedWithCommaAndJSON() {
        // Given
        let encoder = FormURLEncoder(arrayEncodingStrategy: .commaSeparator, nestedEncodingStrategy: .json)
        let parameters = EncodableStruct1()
        
        // When
        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
        
        // Then
        let expected = "one=one&two=2&three=true&four=1%2C2%2C3&five=%7B%22a%22%3A%22a%22%7D&six=%7B%22a%22%3A%7B%22b%22%3A%22b%22%7D%7D&seven=%7B%22a%22%3A%22a%22%7D"
        XCTAssertEqual(result, expected)
    }

	func testThatManuallyEncodableStructCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = ManuallyEncodableStruct()

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// then
		let expected = "root%5Ba%5D%5Bstring%5D=string&root%5B0%5D%5B0%5D=1&root%5B0%5D%5B1%5D=2&root%5B0%5D%5B2%5D=3&root%5B1%5D%5Ba%5D%5Bstring%5D=string&root%5B2%5D%5B0%5D%5B0%5D=1&root%5B2%5D%5B0%5D%5B1%5D=2&root%5B2%5D%5B0%5D%5B2%5D=3"
		// root[a][string]=string&root[0][0]=1&root[0][1]=2&root[0][2]=3root[1][a][string]=string&root[2][0][0]=1&root[2][0][1]=2&root[2][0][2]=3
		XCTAssertEqual(result, expected)
	}

	func testThatArrayNestedDictionaryIntValueCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = ["foo": [["bar": 2], ["qux": 3], ["quy": 4]]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "foo%5B0%5D%5Bbar%5D=2&foo%5B1%5D%5Bqux%5D=3&foo%5B2%5D%5Bquy%5D=4")
	}

	func testThatArrayNestedDictionaryStringValueCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = ["foo": [["bar": "2"], ["qux": "3"], ["quy": "4"]]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "foo%5B0%5D%5Bbar%5D=2&foo%5B1%5D%5Bqux%5D=3&foo%5B2%5D%5Bquy%5D=4")
	}

	func testThatArrayNestedDictionaryBoolValueCanBeEncodedWithIndexInBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .brackets(indexed: true))
		let parameters = ["foo": [["bar": true], ["qux": false], ["quy": true]]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "foo%5B0%5D%5Bbar%5D=true&foo%5B1%5D%5Bqux%5D=false&foo%5B2%5D%5Bquy%5D=true")
	}

	func testThatArraysCanBeEncodedWithoutBrackets() {
		// Given
		let encoder = FormURLEncoder(arrayEncodingStrategy: .repeatKey)
		let parameters = ["array": [1, 2]]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "array=1&array=2")
	}

	//    func testThatArraysCanBeEncodedWithCustomClosure() {
	//        // Given
	//        let encoder = FormURLEncoder(arrayEncodingStrategy: .custom { key, index in
	//            "\(key).\(index + 1)"
	//        })
	//        let parameters = ["array": [1, 2]]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "array.1=1&array.2=2")
	//    }

	func testThatBoolsCanBeNumberEncoded() {
		// Given
		let encoder = FormURLEncoder(boolEncodingStrategy: .numeric)
		let parameters = ["bool": true]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "bool=1")
	}

	func testThatDataCanBeEncoded() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["data": Data("data".utf8)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "data=ZGF0YQ%3D%3D")
	}

	//    func testThatCustomDataEncodingFailsWhenErrorIsThrown() {
	//        // Given
	//        struct DataEncodingError: Error {}
//
	//        let encoder = FormURLEncoder(dataEncoding: .custom { _ in throw DataEncodingError() })
	//        let parameters = ["data": Data("data".utf8)]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertTrue(result.isFailure)
	//    }

	func testThatDatesCanBeEncoded() {
		// Given
		let encoder = FormURLEncoder(dateEncodingStrategy: .deferredToDate)
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "date=123.456")
	}

	func testThatDatesCanBeEncodedAsSecondsSince1970() {
		// Given
		let encoder = FormURLEncoder(dateEncodingStrategy: .secondsSince1970)
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "date=978307323.456")
	}

	func testThatDatesCanBeEncodedAsMillisecondsSince1970() {
		// Given
		let encoder = FormURLEncoder(dateEncodingStrategy: .millisecondsSince1970)
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "date=978307323456.0")
	}

	func testThatDatesCanBeEncodedAsISO8601Formatted() {
		// Given
		let encoder = FormURLEncoder(dateEncodingStrategy: .iso8601)
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "date=2001-01-01T00%3A02%3A03Z")
	}

	func testThatDatesCanBeEncodedAsFormatted() {
		// Given
		let dateFormatter = DateFormatter()
		dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSS"
		dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)

		let encoder = FormURLEncoder(dateEncodingStrategy: .formatted(dateFormatter))
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "date=2001-01-01%2000%3A02%3A03.4560")
	}

	func testThatDatesCanBeEncodedAsCustomFormatted() {
		// Given
		let encoder = FormURLEncoder(dateEncodingStrategy: .custom {
			var container = $1.singleValueContainer()
			try container.encode("\($0.timeIntervalSinceReferenceDate)")
		})
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "date=123.456")
	}

	func testEncoderThrowsErrorWhenCustomDateEncodingFails() {
		// Given
		struct DateEncodingError: Error {}

		let encoder = FormURLEncoder(dateEncodingStrategy: .custom { _, _ in throw DateEncodingError() })
		let parameters = ["date": Date(timeIntervalSinceReferenceDate: 123.456)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertTrue(result == nil)
	}

	func testThatKeysCanBeEncodedIntoSnakeCase() {
		// Given
		let encoder = FormURLEncoder(keyEncodingStrategy: .convertToSnakeCase)
		let parameters = ["oneTwoThree": "oneTwoThree"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "one_two_three=oneTwoThree")
	}

	//    func testThatKeysCanBeEncodedIntoKebabCase() {
	//        // Given
	//        let encoder = FormURLEncoder(keyEncodingStrategy: .convertToKebabCase)
	//        let parameters = ["oneTwoThree": "oneTwoThree"]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "one-two-three=oneTwoThree")
	//    }

	//    func testThatKeysCanBeEncodedIntoACapitalizedString() {
	//        // Given
	//        let encoder = FormURLEncoder(keyEncodingStrategy: .capitalized)
	//        let parameters = ["oneTwoThree": "oneTwoThree"]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "OneTwoThree=oneTwoThree")
	//    }

	//    func testThatKeysCanBeEncodedIntoALowercasedString() {
	//        // Given
	//        let encoder = FormURLEncoder(keyEncodingStrategy: .lowercased)
	//        let parameters = ["oneTwoThree": "oneTwoThree"]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "onetwothree=oneTwoThree")
	//    }
//
	//    func testThatKeysCanBeEncodedIntoAnUppercasedString() {
	//        // Given
	//        let encoder = FormURLEncoder(keyEncodingStrategy: .uppercased)
	//        let parameters = ["oneTwoThree": "oneTwoThree"]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "ONETWOTHREE=oneTwoThree")
	//    }

	func testThatKeysCanBeCustomEncoded() {
		// Given
		let encoder = FormURLEncoder(keyEncodingStrategy: .custom { _ in Key("A") })
		let parameters = ["oneTwoThree": "oneTwoThree"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "A=oneTwoThree")
	}

	func testThatNilCanBeEncodedByDroppingTheKeyByDefault() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: [String: String?] = ["a": nil, "b": ""]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "b=")
	}

	func testThatNilCanBeEncodedInSynthesizedEncodableByDroppingTheKeyByDefault() {
		// Given
		let encoder = FormURLEncoder()

		// When
		let result = try? String(data: encoder.encode(OptionalEncodableStruct()), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "one=one")
	}

	//    func testThatNilCanBeEncodedAsNull() {
	//        // Given
	//        let encoder = FormURLEncoder(nilEncoding: .null)
	//        let parameters: [String: String?] = ["a": nil]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "a=null")
	//    }
//
	//    func testThatNilCanBeEncodedInSynthesizedEncodableAsNull() {
	//        // Given
	//        let encoder = FormURLEncoder(nilEncoding: .null)
//
	//        // When
	//        let result = try? String(data: encoder.encode(OptionalEncodableStruct()), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "one=one&two=null")
	//    }
//
	//    func testThatNilCanBeEncodedByDroppingTheKey() {
	//        // Given
	//        let encoder = FormURLEncoder(nilEncoding: .dropKey)
	//        let parameters: [String: String?] = ["a": nil]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "")
	//    }
//
	//    func testThatNilCanBeEncodedInSynthesizedEncodableByDroppingTheKey() {
	//        // Given
	//        let encoder = FormURLEncoder(nilEncoding: .dropKey)
//
	//        // When
	//        let result = try? String(data: encoder.encode(OptionalEncodableStruct()), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "one=one")
	//    }
//
	//    func testThatNilCanBeEncodedByDroppingTheValue() {
	//        // Given
	//        let encoder = FormURLEncoder(nilEncoding: .dropValue)
	//        let parameters: [String: String?] = ["a": nil]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "a=")
	//    }

	//    func testThatNilCanBeEncodedInSynthesizedEncodableByDroppingTheValue() {
	//        // Given
	//        let encoder = FormURLEncoder(nilEncoding: .dropValue)
//
	//        // When
	//        let result = try? String(data: encoder.encode(OptionalEncodableStruct()), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "one=one&two=")
	//    }

	//    func testThatSpacesCanBeEncodedAsPluses() {
	//        // Given
	//        let encoder = FormURLEncoder(spaceEncoding: .plusReplaced)
	//        let parameters = ["spaces": "replace with spaces"]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "spaces=replace+with+spaces")
	//    }

	//    func testThatEscapedCharactersCanBeCustomized() {
	//        // Given
	//        var allowed = CharacterSet.afURLQueryAllowed
	//        allowed.remove(charactersIn: "?/")
	//        let encoder = FormURLEncoder(allowedCharacters: allowed)
	//        let parameters = ["allowed": "?/"]
//
	//        // When
	//        let result = try? String(data: encoder.encode(parameters), encoding: .utf8)
//
	//        // Then
	//        XCTAssertEqual(result, "allowed=%3F%2F")
	//    }

	func testThatUnreservedCharactersAreNotPercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: OrderedDict = [
			"lowercase": "abcdefghijklmnopqrstuvwxyz",
			"numbers": "0123456789",
			"uppercase": "ABCDEFGHIJKLMNOPQRSTUVWXYZ",
		]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "lowercase=abcdefghijklmnopqrstuvwxyz&numbers=0123456789&uppercase=ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		XCTAssertEqual(result, expected)
	}

	func testThatReservedCharactersArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let generalDelimiters = ":#[]@"
		let subDelimiters = "!$&'()*+,;="
		let parameters = ["reserved": "\(generalDelimiters)\(subDelimiters)"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "reserved=%3A%23%5B%5D%40%21%24%26%27%28%29%2A%2B%2C%3B%3D")
	}
    
    func testSpotifyQuery() throws {
        let url = try APIClient.test
            .query("q", "remaster%20track:Doxy%20artist:Miles%20Davis")
            .withRequest { components, _ in
                components.url!
            }
        XCTAssertEqual(url.absoluteString, "https://example.com?q=remaster%2520track%3ADoxy%2520artist%3AMiles%2520Davis")
    }

	func testThatIllegalASCIICharactersArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["illegal": " \"#%<>[]\\^`{}|"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "illegal=%20%22%23%25%3C%3E%5B%5D%5C%5E%60%7B%7D%7C")
	}

	func testThatAmpersandsInKeysAndValuesArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: OrderedDict = ["foo&bar": "baz&qux", "foobar": "bazqux"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "foo%26bar=baz%26qux&foobar=bazqux")
	}

	func testThatQuestionMarksInKeysAndValuesAreNotPercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["?foo?": "?bar?"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "?foo?=?bar?")
	}

	func testThatSlashesInKeysAndValuesAreNotPercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["foo": "/bar/baz/qux"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "foo=/bar/baz/qux")
	}

	func testThatSpacesInKeysAndValuesArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = [" foo ": " bar "]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "%20foo%20=%20bar%20")
	}

	func testThatPlusesInKeysAndValuesArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["+foo+": "+bar+"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "%2Bfoo%2B=%2Bbar%2B")
	}

	func testThatPercentsInKeysAndValuesArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters = ["percent%": "%25"]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		XCTAssertEqual(result, "percent%25=%2525")
	}

	func testThatNonLatinCharactersArePercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let parameters: OrderedDict = [
			"french": "français",
			"japanese": "日本語",
			"arabic": "العربية",
			"emoji": "😃",
		]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let expected = "french=fran%C3%A7ais&japanese=%E6%97%A5%E6%9C%AC%E8%AA%9E&arabic=%D8%A7%D9%84%D8%B9%D8%B1%D8%A8%D9%8A%D8%A9&emoji=%F0%9F%98%83"
		XCTAssertEqual(result, expected)
	}

	func testStringWithThousandsOfChineseCharactersIsPercentEscaped() {
		// Given
		let encoder = FormURLEncoder()
		let repeatedCount = 2000
		let parameters = ["chinese": String(repeating: "一二三四五六七八九十", count: repeatedCount)]

		// When
		let result = try? String(data: encoder.encode(parameters), encoding: .utf8)

		// Then
		let escaped = String(repeating: "%E4%B8%80%E4%BA%8C%E4%B8%89%E5%9B%9B%E4%BA%94%E5%85%AD%E4%B8%83%E5%85%AB%E4%B9%9D%E5%8D%81",
		                     count: repeatedCount)
		let expected = "chinese=\(escaped)"
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

struct OrderedDict: ExpressibleByDictionaryLiteral, Encodable {

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

struct TestQuery: Codable {
	var property = "property"
}

struct Key: CodingKey {

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
