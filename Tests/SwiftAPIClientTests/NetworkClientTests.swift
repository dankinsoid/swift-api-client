import Foundation
import Logging
@testable import SwiftAPIClient
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class APIClientTests: XCTestCase {

	func testInitWithBaseURL() throws {
		let url = URL(string: "https://example.com")!
		let client = APIClient(baseURL: url)
		let request = try client.request()
		XCTAssertEqual(request, HTTPRequest(url: url))
	}

	func testInitWithRequest() throws {
		let request = HTTPRequest(url: URL(string: "https://example.com")!)
		let client = APIClient(request: request)
		let resultRequest = try client.request()
		XCTAssertEqual(request, resultRequest)
	}

	func testModifyRequest() throws {
        let method: HTTPRequest.Method = .patch
		let client = APIClient.test
			.modifyRequest { request in
				request.method = method
			}
		let request = try client.request()
		XCTAssertEqual(request.method, method)
	}

	func testWithRequest() throws {
		let client = APIClient.test
		let result = try client.withRequest { request, _ in
			request.url?.absoluteString
		}
		XCTAssertEqual(result, "https://example.com")
	}

	func testWithConfigs() throws {
		let client = APIClient.test
		let enabled = client
			.configs(\.testValue, true)
			.withConfigs(\.testValue)

		XCTAssertTrue(enabled)

		let disabled = client
			.configs(\.testValue, false)
			.withConfigs(\.testValue)

		XCTAssertFalse(disabled)
	}

	func testConfigsOrder() throws {
		let client = APIClient.test
		let (request, configs) = try client
			.configs(\.intValue, 1)
			.query {
				[URLQueryItem(name: "0", value: "\($0.intValue)")]
			}
			.configs(\.intValue, 2)
			.query {
				[URLQueryItem(name: "1", value: "\($0.intValue)")]
			}
			.configs(\.intValue, 3)
			.query {
				[URLQueryItem(name: "2", value: "\($0.intValue)")]
			}
			.withRequest { request, configs in
				(request, configs)
			}

		XCTAssertEqual(request.url?.query, "0=3&1=3&2=3")
		XCTAssertEqual(configs.intValue, 3)
	}

	func testConfigs() throws {
		let enabled = APIClient.test
			.configs(\.testValue, true)
			.withConfigs(\.testValue)

		XCTAssertTrue(enabled)

		let disabled = APIClient.test
			.configs(\.testValue, false)
			.withConfigs(\.testValue)

		XCTAssertFalse(disabled)
	}
}

extension APIClient.Configs {

	var testValue: Bool {
		get { self[\.testValue] ?? false }
		set { self[\.testValue] = newValue }
	}

	var intValue: Int {
		get { self[\.intValue] ?? 0 }
		set { self[\.intValue] = newValue }
	}
}
