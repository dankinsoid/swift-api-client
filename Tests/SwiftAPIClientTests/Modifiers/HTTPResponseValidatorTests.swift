import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class HTTPResponseValidatorTests: XCTestCase {

	func testStatusCodeValidator() throws {
		let validator = HTTPResponseValidator.statusCode(200 ... 299)
		let response = HTTPResponse(status: 200)
		let data = Data()
		let configs = APIClient.Configs()

		// Validation should pass for a status code within the range
		XCTAssertNoThrow(try validator.validate(response, data, configs))

		// Validation should throw an error for a status code outside the range
		let invalidResponse = HTTPResponse(status: 400)
		XCTAssertThrowsError(try validator.validate(invalidResponse, data, configs))
	}

	func testAlwaysSuccessValidator() throws {
		let validator = HTTPResponseValidator.alwaysSuccess
		let response = HTTPResponse(status: 200)
		let data = Data()
		let configs = APIClient.Configs()

		// Validation should always pass without throwing any errors
		XCTAssertNoThrow(try validator.validate(response, data, configs))
	}

	static var allTests = [
		("testStatusCodeValidator", testStatusCodeValidator),
		("testAlwaysSuccessValidator", testAlwaysSuccessValidator),
	]
}
