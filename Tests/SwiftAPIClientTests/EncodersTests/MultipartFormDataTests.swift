import Foundation
import SwiftAPIClient
import XCTest

class MultipartFormDataTests: XCTestCase {

	private struct TestCase {
		let multipartFormData: MultipartFormData
		let expected: String
	}

	func testAsData() {
		let testCases: [UInt: TestCase] = [
			#line: TestCase(
				multipartFormData: MultipartFormData(
					parts: [
						MultipartFormData.Part(
							name: "field1",
							filename: nil,
							mimeType: nil,
							data: "value1".data(using: .utf8)!
						),
						MultipartFormData.Part(
							name: "field2",
							filename: "example.txt",
							mimeType: .text(.plain),
							data: "value2".data(using: .utf8)!
						),
					],
					boundary: "boundary"
				),
				expected: [
					"--boundary",
					"Content-Disposition: form-data; name=\"field1\"",
					"",
					"value1",
					"--boundary",
					"Content-Disposition: form-data; name=\"field2\"; filename=\"example.txt\"",
					"Content-Type: text/plain",
					"",
					"value2",
					"--boundary--",
				].joined(separator: "\r\n") + "\r\n"
			),
		]

		for (_, testCase) in testCases {
			let actual = String(data: testCase.multipartFormData.data, encoding: .utf8)
			let expected = testCase.expected

			XCTAssertEqual(actual, expected)
		}
	}
}
