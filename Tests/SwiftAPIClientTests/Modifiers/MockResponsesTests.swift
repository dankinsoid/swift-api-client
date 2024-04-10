@preconcurrency import Foundation
@testable import SwiftAPIClient
#if canImport(FoundationNetworking)
@preconcurrency import FoundationNetworking
#endif
import XCTest

final class MockResponsesTests: XCTestCase {

	func testMock() throws {
		let client = APIClient(baseURL: URL(string: "https://example.com")!)
		let mockValue = "Mock Response"
		let modifiedClient = client.mock(mockValue)

		try XCTAssertEqual(modifiedClient.usingMocks(policy: .ifSpecified).configs().getMockIfNeeded(for: String.self), mockValue)
		try XCTAssertEqual(modifiedClient.usingMocks(policy: .ignore).configs().getMockIfNeeded(for: String.self), nil)
		XCTAssertThrowsError(try modifiedClient.usingMocks(policy: .require).configs().getMockIfNeeded(for: Int.self))
	}
}
