import Foundation
@testable import SwiftNetworkingCore
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class NetworkClientTests: XCTestCase {

	func testInitWithBaseURL() throws {
		let url = URL(string: "https://example.com")!
		let client = NetworkClient(baseURL: url)
		let request = try client.request()
		XCTAssertEqual(request, URLRequest(url: url))
	}

	func testInitWithRequest() throws {
		let request = URLRequest(url: URL(string: "https://example.com")!)
		let client = NetworkClient(request: request)
		let resultRequest = try client.request()
		XCTAssertEqual(request, resultRequest)
	}

	func testmodifyRequest() throws {
		let interval: TimeInterval = 30
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!)
			.modifyRequest { request in
				request.timeoutInterval = interval
			}
		let request = try client.request()
		XCTAssertEqual(request.timeoutInterval, interval)
	}

	func testWithRequest() throws {
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!)
		let result = try client.withRequest { request, _ in
			request.url?.absoluteString == "https://example.com"
		}
		XCTAssertTrue(result)
	}

	func testWithConfigs() throws {
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!)
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
