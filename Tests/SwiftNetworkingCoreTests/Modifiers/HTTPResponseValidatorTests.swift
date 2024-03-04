import Foundation
import SwiftNetworkingCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class HTTPResponseValidatorTests: XCTestCase {

	func testStatusCodeValidator() throws {
		let validator = HTTPResponseValidator.statusCode(200 ... 299)
		let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		let data = Data()
        let configs = NetworkClient.Configs { _ in
            URLRequest(url: URL(string: "https://example.com")!)
        }

		// Validation should pass for a status code within the range
		XCTAssertNoThrow(try validator.validate(response, data, configs))

		// Validation should throw an error for a status code outside the range
		let invalidResponse = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 400, httpVersion: nil, headerFields: nil)!
		XCTAssertThrowsError(try validator.validate(invalidResponse, data, configs))
	}

	func testAlwaysSuccessValidator() throws {
		let validator = HTTPResponseValidator.alwaysSuccess
		let response = HTTPURLResponse(url: URL(string: "https://example.com")!, statusCode: 200, httpVersion: nil, headerFields: nil)!
		let data = Data()
        let configs = NetworkClient.Configs { _ in
            URLRequest(url: URL(string: "https://example.com")!)
        }

		// Validation should always pass without throwing any errors
		XCTAssertNoThrow(try validator.validate(response, data, configs))
	}

	static var allTests = [
		("testStatusCodeValidator", testStatusCodeValidator),
		("testAlwaysSuccessValidator", testAlwaysSuccessValidator),
	]
}
