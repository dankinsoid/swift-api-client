import Foundation
import Logging
@testable import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class LogLevelModifierTests: XCTestCase {

	func testLogLevel() {
		let client = APIClient(baseURL: URL(string: "https://example.com")!)
		let modifiedClient = client.log(level: .debug)

		XCTAssertEqual(modifiedClient.configs().logLevel, .debug)
	}

	func testLogger() {
		let client = APIClient(baseURL: URL(string: "https://example.com")!)
		let modifiedClient = client.log(level: .info)

		XCTAssertEqual(modifiedClient.configs().logger.logLevel, .info)
	}
}
