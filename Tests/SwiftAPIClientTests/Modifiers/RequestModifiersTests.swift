import Foundation
@testable import SwiftAPIClient
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RequestModifiersTests: XCTestCase {

	let client = APIClient(baseURL: URL(string: "https://example.com")!)

	func testPathAppending() throws {

		let modifiedClient = client.path("users", "123")

		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "https://example.com/users/123/")
	}

	func testMethodSetting() throws {
		let modifiedClient = client.method(.post)

		try XCTAssertEqual(modifiedClient.request().method, .post)
	}

	func testHeadersAdding() throws {
		let modifiedClient = client.headers(
			.accept(.application(.json)),
			.contentType(.application(.json))
		)

		try XCTAssertEqual(modifiedClient.request().headerFields[.accept], "application/json")
		try XCTAssertEqual(modifiedClient.request().headerFields[.contentType], "application/json")
	}

	func testHeaderRemoving() throws {
		let modifiedClient = client
			.headers(.accept(.application(.json)))
			.removeHeader(.accept)

		try XCTAssertNil(modifiedClient.request().headerFields[.accept])
	}

	func testHeaderUpdating() throws {
		let client = APIClient(baseURL: URL(string: "https://example.com")!)

		let modifiedClient = client
			.headers(HTTPField.accept(.application(.json)))
			.headers(HTTPField.accept(.application(.xml)), removeCurrent: true)

		try XCTAssertEqual(modifiedClient.request().headerFields[.accept], "application/xml")
	}

	func testBodySetting() throws {
		let modifiedClient = client.body(["name": "John"])
		let body = try modifiedClient.withConfigs { try $0.body?($0) }
		XCTAssertNotNil(body)
		XCTAssertEqual(body, try? JSONSerialization.data(withJSONObject: ["name": "John"]))
		try XCTAssertEqual(modifiedClient.request().headerFields[.contentType], "application/json")
	}

	func testQueryParametersAdding() throws {
		let modifiedClient = client.query("page", "some parameter ❤️")

		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "https://example.com/?page=some%20parameter%20%E2%9D%A4%EF%B8%8F")
	}

	func testBaseURLSetting() throws {
		let modifiedClient = client.query("test", "value").baseURL(URL(string: "http://test.net")!)
		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "http://test.net/?test=value")
	}

	func testRemoveSlaahIfNeeded() throws {
		let modifiedClient = client.query("test", "value").modifyRequest {
			$0.path = $0.path?.replacingOccurrences(of: "/?", with: "?")
		}
		try XCTAssertEqual(modifiedClient.request().url?.absoluteString, "https://example.com?test=value")
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

	func testTimeoutIntervalSetting() throws {
		let modifiedClient = client.timeoutInterval(30)
		XCTAssertEqual(modifiedClient.withConfigs(\.timeoutInterval), 30)
	}
}
