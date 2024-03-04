#if canImport(Reachability)
import Foundation
import Reachability
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
@testable import SwiftNetworkingCore
import XCTest

final class NetworkClientReachabilityTests: XCTestCase {

	func testWaitForConnection() async throws {
		// Create a mock reachability service
		let reachabilityService = TestReachibilityService()

		// Create a network client
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!)
			.httpClient(.test())
			.waitForConnection(reachabilityService: reachabilityService)

		// Verify that the modified client retries the request when network is unreachable
		reachabilityService.connection = .wifi
		try await client.httpTest()

		XCTAssertEqual(reachabilityService.callsCount, 1)
		XCTAssertEqual(reachabilityService.successCallsCount, 1)

		// Verify that the modified client does not retry the request when network is reachable
		reachabilityService.connection = .unavailable
		try await client.httpTest()
		XCTAssertEqual(reachabilityService.callsCount, 2)
		XCTAssertEqual(reachabilityService.successCallsCount, 1)
	}
}

final class TestReachibilityService: ReachabilityService {

	var connection: Reachability.Connection = .wifi
	var callsCount = 0
	var successCallsCount = 0

	func wait(for connection: @escaping (Reachability.Connection) -> Bool) async {
		callsCount += 1
		if connection(self.connection) {
			successCallsCount += 1
		}
	}
}
#endif
