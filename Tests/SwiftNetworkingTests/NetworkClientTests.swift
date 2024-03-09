import Foundation
import Logging
@testable import SwiftNetworking
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

	func testModifyRequest() throws {
		let interval: TimeInterval = 30
		let client = NetworkClient.test
			.modifyRequest { request in
				request.timeoutInterval = interval
			}
		let request = try client.request()
		XCTAssertEqual(request.timeoutInterval, interval)
	}

	func testWithRequest() throws {
		let client = NetworkClient.test
		let result = try client.withRequest { request, _ in
			request.url?.absoluteString == "https://example.com"
		}
		XCTAssertTrue(result)
	}

	func testWithConfigs() throws {
		let client = NetworkClient.test
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
		let client = NetworkClient.test
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
        let enabled = NetworkClient.test
            .configs(\.testValue, true)
            .withConfigs(\.testValue)
        
        XCTAssertTrue(enabled)
        
        let disabled = NetworkClient.test
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
    
    var intValue: Int {
        get { self[\.intValue] ?? 0 }
        set { self[\.intValue] = newValue }
    }
}
