import Foundation
@testable import SwiftNetworkingCore
import XCTest
import Logging
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

    func testLogging() async throws {
//        LoggingSystem.bootstrap { _ in
//            PrintLogger()
//        }
        let client = NetworkClient(baseURL: URL(string: "https://example.com/petstore")!)
            .body(["eee": 2])
            .put
            .loggingComponents(.standart)
        try await client.httpTest { _, _ in
            Data(#"{"success": true}"#.utf8)
        }
    }
}

struct PrintLogger: LogHandler {
    
    var metadata: Logging.Logger.Metadata = [:]
    var logLevel: Logging.Logger.Level = .info
    subscript(metadataKey key: String) -> Logging.Logger.Metadata.Value? {
        get { metadata[key] }
        set { metadata[key] = newValue }
    }
    
    func log(
        level: Logger.Level,
        message: Logger.Message,
        metadata: Logger.Metadata?,
        source: String,
        file: String,
        function: String,
        line: UInt
    ) {
        guard self.logLevel <= level else { return }
        print(message)
    }
}
