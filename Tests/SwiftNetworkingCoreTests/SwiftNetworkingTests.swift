import Foundation
@testable import SwiftNetworkingCore
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class SwiftNetworkingTests: XCTestCase {

	private let client = NetworkClient(baseURL: URL(string: "https://tests.com")!)

	func testConfigs() throws {
		let enabled = client
			.configs(\.testValue, true)
			.withConfigs(\.testValue)

		XCTAssertTrue(enabled)

		let disabled = client
			.configs(\.testValue, false)
			.withConfigs(\.testValue)

		XCTAssertFalse(disabled)
	}
}

extension NetworkClient.Configs {

	var testValue: Bool {
		get { self[\.testValue] ?? false }
		set { self[\.testValue] = newValue }
	}
}
