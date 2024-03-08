import Foundation
@testable import SwiftNetworkingCore
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RequestModifiersTests: XCTestCase {

	let client = NetworkClient(baseURL: URL(string: "https://example.com")!)

	func testPathAppending() throws {

		let modifiedClient = client.path("users", "123")

		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "https://example.com/users/123")
	}

	func testMethodSetting() throws {
		let modifiedClient = client.method(.post)

		try XCTAssertEqual(modifiedClient.request().httpMethod, "POST")
	}

	func testHeadersAdding() throws {
		let modifiedClient = client.headers(
			.accept(.application(.json)),
			.contentType(.application(.json))
		)

		try XCTAssertEqual(modifiedClient.request().allHTTPHeaderFields?["Accept"], "application/json")
		try XCTAssertEqual(modifiedClient.request().allHTTPHeaderFields?["Content-Type"], "application/json")
	}

	func testHeaderRemoving() throws {
		let modifiedClient = client
			.headers(.accept(.application(.json)))
			.removeHeader(.accept)

		try XCTAssertNil(modifiedClient.request().allHTTPHeaderFields?["Accept"])
	}

	func testHeaderUpdating() throws {
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!)

		let modifiedClient = client
			.headers(HTTPHeader.accept(.application(.json)))
			.headers(HTTPHeader.accept(.application(.xml)), update: true)

		try XCTAssertEqual(modifiedClient.request().allHTTPHeaderFields?["Accept"], "application/xml")
	}

	func testBodySetting() throws {
		let modifiedClient = client.body(["name": "John"])
		try XCTAssertEqual(modifiedClient.request().httpBody, try? JSONSerialization.data(withJSONObject: ["name": "John"]))
		try XCTAssertEqual(modifiedClient.request().allHTTPHeaderFields?["Content-Type"], "application/json")
	}

	func testQueryParametersAdding() throws {
		let modifiedClient = client.query("page", "some parameter ❤️")

		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "https://example.com?page=some%20parameter%20%E2%9D%A4%EF%B8%8F")
	}

	func testBaseURLSetting() throws {
		let modifiedClient = client.query("test", "value").baseURL(URL(string: "http://test.net")!)

		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "http://test.net?test=value")
	}

	func testSchemeSetting() throws {
		let modifiedClient = client.scheme("http")

		try XCTAssertEqual(modifiedClient.request().url?.scheme, "http")
	}

	func testHostSetting() throws {
		let modifiedClient = client.host("api.example.com")

		try XCTAssertEqual(modifiedClient.request().url?.host, "api.example.com")
	}

	func testPortSetting() throws {
		let modifiedClient = client.port(8080)

		try XCTAssertEqual(modifiedClient.request().url?.port, 8080)
	}

	func testURLComponentsModification() throws {
		let modifiedClient = client.modifyURLComponents { components in
			components.scheme = "http"
			components.host = "api.example.com"
			components.port = 8080
		}

		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "http://api.example.com:8080")
	}

	func testTimeoutIntervalSetting() throws {
		let modifiedClient = client.timeoutInterval(30)

		try XCTAssertEqual(modifiedClient.request().timeoutInterval, 30)
	}
}
