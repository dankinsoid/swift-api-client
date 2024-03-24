import Foundation
@testable import SwiftAPIClient
import XCTest

class AuthorityTests: XCTestCase {

	func testCompleteAuthority() {
		let authority = Authority("user:password@www.example.com:8080")
		XCTAssertEqual(authority.description, "user:password@www.example.com:8080")
		XCTAssertEqual(authority.userinfo, "user:password")
		XCTAssertEqual(authority.host, "www.example.com")
		XCTAssertEqual(authority.port, 8080)
	}

	func testAuthorityWithoutUserinfo() {
		let authority = Authority("www.example.com:8080")
		XCTAssertEqual(authority.description, "www.example.com:8080")
		XCTAssertNil(authority.userinfo)
		XCTAssertEqual(authority.host, "www.example.com")
		XCTAssertEqual(authority.port, 8080)
	}

	func testAuthorityWithoutPort() {
		let authority = Authority("user:password@www.example.com")
		XCTAssertEqual(authority.description, "user:password@www.example.com")
		XCTAssertEqual(authority.userinfo, "user:password")
		XCTAssertEqual(authority.host, "www.example.com")
		XCTAssertNil(authority.port)
	}

	func testAuthorityWithOnlyHost() {
		let authority = Authority("www.example.com")
		XCTAssertEqual(authority.description, "www.example.com")
		XCTAssertNil(authority.userinfo)
		XCTAssertEqual(authority.host, "www.example.com")
		XCTAssertNil(authority.port)
	}

	func testInvalidPortAuthority() {
		let authority = Authority("user:password@www.example.com:notanumber")
		XCTAssertEqual(authority.description, "user:password@www.example.com:notanumber")
		XCTAssertEqual(authority.userinfo, "user:password")
		// Since the port is not valid, it should not parse it and leave the rest as part of the host
		XCTAssertEqual(authority.host, "www.example.com:notanumber")
		XCTAssertNil(authority.port)
	}

	func testEmptyAuthority() {
		let authority = Authority("")
		XCTAssertEqual(authority.description, "")
		XCTAssertNil(authority.userinfo)
		XCTAssertEqual(authority.host, "")
		XCTAssertNil(authority.port)
	}

	func testAuthorityWithoutUserinfoAndPort() {
		let authority = Authority("www.example.com")
		XCTAssertEqual(authority.description, "www.example.com")
		XCTAssertNil(authority.userinfo)
		XCTAssertEqual(authority.host, "www.example.com")
		XCTAssertNil(authority.port)
	}

	func testCustomInit() {
		let authority = Authority(userinfo: "admin", host: "localhost", port: 22)
		XCTAssertEqual(authority.description, "admin@localhost:22")
		XCTAssertEqual(authority.userinfo, "admin")
		XCTAssertEqual(authority.host, "localhost")
		XCTAssertEqual(authority.port, 22)
	}
}
