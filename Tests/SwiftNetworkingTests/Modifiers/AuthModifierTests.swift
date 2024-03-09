import Foundation
@testable import SwiftNetworking
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class AuthModifierTests: XCTestCase {

	let client = NetworkClient(baseURL: URL(string: "https://example.com")!)

	func testAuthEnabled() throws {
		let client = client.auth(.header("Bearer token"))
		let enabledClient = client.auth(enabled: true)
		let authorizedRequest = try enabledClient.request()
		XCTAssertEqual(authorizedRequest.value(forHTTPHeaderField: "Authorization"), "Bearer token")
	}

	func testAuthDisabled() throws {
		let client = client.auth(.header("Bearer token"))
		let disabledClient = client.auth(enabled: false)
		let unauthorizedRequest = try disabledClient.request()
		XCTAssertNil(unauthorizedRequest.value(forHTTPHeaderField: "Authorization"))
	}

	func testAuthBearer() throws {
		let token = "token"
		let request = try client.auth(.bearer(token: token)).request()
		let header = request.headers[.authorization]
		XCTAssertEqual(header, "Bearer token")
	}

	func testAuthBasic() throws {
		let username = "username"
		let password = "password"
		let request = try client.auth(.basic(username: username, password: password)).request()
		let header = request.headers[.authorization]
		XCTAssertEqual(header, "Basic dXNlcm5hbWU6cGFzc3dvcmQ=")
	}
}
