import Foundation
@testable import SwiftAPIClient
import XCTest

class URLComponentBuilderTests: XCTestCase {
    
    // MARK: - URLComponents Tests
    
    func testURLComponentsConfigureURLComponents() {
        var components = URLComponents()
        let result = components.configureURLComponents { components in
            components.scheme = "https"
            components.host = "example.com"
        }
        XCTAssertEqual(result.scheme, "https")
        XCTAssertEqual(result.host, "example.com")
    }
    
    func testURLComponentsPath() {
        var components = URLComponents()
        let result = components.path("path1", "path2")
        XCTAssertEqual(result.path, "/path1/path2")
    }
    
    func testURLComponentsQuery() throws {
        var components = URLComponents()
        let result = components.query(["key1": "value1", "key2": 2])
        XCTAssertEqual(result.queryItems?.count, 2)
        XCTAssertEqual(result.queryItems?.first?.name, "key1")
        XCTAssertEqual(result.queryItems?.first?.value, "value1")
    }
    
    // MARK: - URL Tests
    
    func testURLConfigureURLComponents() {
        let url = URL(string: "https://example.com")!
        let result = url.configureURLComponents { components in
            components.path = "/test"
        }
        XCTAssertEqual(result.path, "/test")
    }
    
    func testURLPath() {
        let url = URL(string: "https://example.com")!.query("service", "spotify")
        let result = url.path("path1", "path2")
        XCTAssertEqual(result.path, "/path1/path2")
    }
    
    func testURLQuery() throws {
        let url = URL(string: "https://example.com")!
        let result = url.query(["key1": "value1", "key2": 2])
        XCTAssertEqual(result.query, "key1=value1&key2=2")
    }
    
    // MARK: - HTTPRequestComponents Tests
    
    func testHTTPRequestComponentsConfigureURLComponents() {
        var requestComponents = HTTPRequestComponents()
        let result = requestComponents.configureURLComponents { components in
            components.scheme = "https"
            components.host = "example.com"
        }
        XCTAssertEqual(result.urlComponents.scheme, "https")
        XCTAssertEqual(result.urlComponents.host, "example.com")
    }
    
    func testHTTPRequestComponentsPath() {
        var requestComponents = HTTPRequestComponents()
        let result = requestComponents.path("path1", "path2")
        XCTAssertEqual(result.urlComponents.path, "/path1/path2")
    }
    
    func testHTTPRequestComponentsQuery() throws {
        var requestComponents = HTTPRequestComponents()
        let result = requestComponents.query(["key1": "value1", "key2": 2])
        XCTAssertEqual(result.urlComponents.queryItems?.count, 2)
        XCTAssertEqual(result.urlComponents.queryItems?.first?.name, "key1")
        XCTAssertEqual(result.urlComponents.queryItems?.first?.value, "value1")
    }
}
