import Foundation
@testable import SwiftAPIClientCore
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class URLSessionConfigurationTests: XCTestCase {

	let client = APIClient(baseURL: URL(string: "https://example.com")!)

	func testDefaultClientsShareTheDefaultSession() {
		let first = client.withConfigs(\.urlSession)
		let second = client.path("other").withConfigs(\.urlSession)
		XCTAssertTrue(first === second)
		XCTAssertNotNil(first.configuration.urlCache)
	}

	func testSessionUsesTheGivenConfiguration() {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.urlCache = nil
		configuration.requestCachePolicy = .reloadIgnoringLocalCacheData

		let session = client.urlSession(configuration: configuration).withConfigs(\.urlSession)

		XCTAssertNil(session.configuration.urlCache)
		XCTAssertEqual(session.configuration.requestCachePolicy, .reloadIgnoringLocalCacheData)
		XCTAssertFalse(session === client.withConfigs(\.urlSession))
	}

	func testClientsWithTheSameConfigurationShareASession() {
		let configured = client.urlSession(configuration: .ephemeral)

		let first = configured.withConfigs(\.urlSession)
		let second = configured.path("users").header(.accept, "*/*").withConfigs(\.urlSession)

		XCTAssertTrue(first === second)
	}

	func testDistinctConfigurationsGetDistinctSessions() {
		let first = client.urlSession(configuration: .ephemeral).withConfigs(\.urlSession)
		let second = client.urlSession(configuration: .ephemeral).withConfigs(\.urlSession)

		XCTAssertFalse(first === second)
	}

	func testDefaultHeadersAreAddedUnlessOverridden() throws {
		let configuration = URLSessionConfiguration.ephemeral
		configuration.httpAdditionalHeaders = ["User-Agent": "custom", "X-Extra": "1"]

		let session = client.urlSession(configuration: configuration).withConfigs(\.urlSession)
		let headers = try XCTUnwrap(session.configuration.httpAdditionalHeaders as? [String: String])

		XCTAssertEqual(headers["User-Agent"], "custom")
		XCTAssertEqual(headers["X-Extra"], "1")
		XCTAssertEqual(headers["Accept-Encoding"], HTTPField.defaultAcceptEncoding.value)
		XCTAssertEqual(configuration.httpAdditionalHeaders?.count, 2, "The caller's configuration must stay untouched")
	}
}
