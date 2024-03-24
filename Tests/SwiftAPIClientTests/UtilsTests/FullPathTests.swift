import Foundation
@testable import SwiftAPIClient
import XCTest

final class FullPathTests: XCTestCase {

	func testOnlyPath() {
		let fullPath = FullPath("/user/profile")
		XCTAssertEqual(fullPath.description, "/user/profile")
		XCTAssertEqual(fullPath.path, ["", "user", "profile"])
		XCTAssertTrue(fullPath.queryItems.isEmpty)
		XCTAssertNil(fullPath.fragment)
	}

	func testPathWithQuery() {
		let fullPath = FullPath("/search?query=swift&sort=desc")
		XCTAssertEqual(fullPath.description, "/search?query=swift&sort=desc")
		XCTAssertEqual(fullPath.path, ["", "search"])
		XCTAssertEqual(fullPath.queryItems.count, 2)
		XCTAssert(fullPath.queryItems.contains(URLQueryItem(name: "query", value: "swift")))
		XCTAssert(fullPath.queryItems.contains(URLQueryItem(name: "sort", value: "desc")))
		XCTAssertNil(fullPath.fragment)
	}

	func testPathWithFragment() {
		let fullPath = FullPath("/help#section1")
		XCTAssertEqual(fullPath.description, "/help#section1")
		XCTAssertEqual(fullPath.path, ["", "help"])
		XCTAssertTrue(fullPath.queryItems.isEmpty)
		XCTAssertEqual(fullPath.fragment, "section1")
	}

	func testCompletePath() {
		let fullPath = FullPath("/user/edit?active=true#permissions")
		XCTAssertEqual(fullPath.description, "/user/edit?active=true#permissions")
		XCTAssertEqual(fullPath.path, ["", "user", "edit"])
		XCTAssertEqual(fullPath.queryItems, [URLQueryItem(name: "active", value: "true")])
		XCTAssertEqual(fullPath.fragment, "permissions")
	}

	func testCompletePathWithSlash() {
		let fullPath = FullPath("/user/edit/?active=true#permissions")
		XCTAssertEqual(fullPath.description, "/user/edit/?active=true#permissions")
		XCTAssertEqual(fullPath.path, ["", "user", "edit", ""])
		XCTAssertEqual(fullPath.queryItems, [URLQueryItem(name: "active", value: "true")])
		XCTAssertEqual(fullPath.fragment, "permissions")
	}

	func testEmptyPath() {
		let fullPath = FullPath("")
		XCTAssertEqual(fullPath.description, "")
	}

	func testSlashPath() {
		let fullPath = FullPath("/")
		XCTAssertEqual(fullPath.description, "/")
	}

	func testPathWithOnlyFragment() {
		let fullPath = FullPath("#settings")
		XCTAssertEqual(fullPath.description, "#settings")
		XCTAssertTrue(fullPath.path.isEmpty)
		XCTAssertTrue(fullPath.queryItems.isEmpty)
		XCTAssertEqual(fullPath.fragment, "settings")
	}

	func testPathWithOnlyQuery() {
		let fullPath = FullPath("?mode=dark")
		XCTAssertEqual(fullPath.description, "?mode=dark")
		XCTAssertTrue(fullPath.path.isEmpty)
		XCTAssertEqual(fullPath.queryItems, [URLQueryItem(name: "mode", value: "dark")])
		XCTAssertNil(fullPath.fragment)
	}

	func testInvalidPath() {
		let fullPath = FullPath("JustSomeRandomString")
		XCTAssertEqual(fullPath.description, "JustSomeRandomString")
		XCTAssertFalse(fullPath.path.isEmpty)
		XCTAssertTrue(fullPath.queryItems.isEmpty)
		XCTAssertNil(fullPath.fragment)
	}
}
