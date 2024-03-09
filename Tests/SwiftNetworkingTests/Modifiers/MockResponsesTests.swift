import Foundation
@testable import SwiftNetworking
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class MockResponsesTests: XCTestCase {

	func testMock() throws {
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!)
		let mockValue = "Mock Response"
		let modifiedClient = client.mock(mockValue)

		try XCTAssertEqual(modifiedClient.usingMocks(policy: .ifSpecified).configs().getMockIfNeeded(for: String.self), mockValue)
		try XCTAssertEqual(modifiedClient.usingMocks(policy: .ignore).configs().getMockIfNeeded(for: String.self), nil)
		XCTAssertThrowsError(try modifiedClient.usingMocks(policy: .require).configs().getMockIfNeeded(for: Int.self))
	}
}
