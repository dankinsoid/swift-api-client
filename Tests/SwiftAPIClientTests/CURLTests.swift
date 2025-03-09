import XCTest
@testable import SwiftAPIClient

final class CURLTests: XCTestCase {

    func testBasicGETRequest() throws {
        let curl = """
        curl 'https://example.com/api/v1/users' \
            -X GET \
            -H 'Accept: application/json'
        """
        
        let components = try HTTPRequestComponents(curl: curl)
        
        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .get)
        XCTAssertEqual(components.headers[.accept], "application/json")
        XCTAssertNil(components.body)
    }

    func testPOSTRequestWithBody() throws {
        let curl = """
        curl 'https://example.com/api/v1/users' \
            -X POST \
            -H 'Content-Type: application/json' \
            -d '{"name":"John","age":30}'
        """
        
        let components = try HTTPRequestComponents(curl: curl)
        
        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .post)
        XCTAssertEqual(components.headers[.contentType], "application/json")
        
        switch components.body {
        case .data(let data):
            let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(body?["name"] as? String, "John")
            XCTAssertEqual(body?["age"] as? Int, 30)
        default:
            XCTFail("Expected data body")
        }
    }

    func testRequestWithMultipleHeaders() throws {
        let curl = """
        curl 'https://example.com/api/v1/users' \
            -X GET \
            -H 'Accept: application/json' \
            -H 'Authorization: Bearer token123'
        """
        
        let components = try HTTPRequestComponents(curl: curl)
        
        XCTAssertEqual(components.headers[.accept], "application/json")
        XCTAssertEqual(components.headers[.authorization], "Bearer token123")
    }

    func testInvalidCURLCommand() {
        let invalidCurl = "invalid curl command"
        
        XCTAssertThrowsError(try HTTPRequestComponents(curl: invalidCurl)) { error in
            XCTAssertEqual((error as? Errors)?.description, "Invalid cURL command")
        }
    }

    func testCURLStringGeneration() throws {
        let components = HTTPRequestComponents(
            url: URL(string: "https://example.com/api/v1/users")!,
            method: .post,
            headers: [
                .contentType: "application/json",
                .accept: "application/json"
            ],
            body: .data(try JSONSerialization.data(withJSONObject: ["name": "John"]))
        
        let expectedCurl = """
        curl 'https://example.com/api/v1/users' \
            -X POST \
            -H 'Content-Type: application/json' \
            -H 'Accept: application/json' \
            -d '{"name":"John"}'
        """
        
        XCTAssertEqual(components.curl, expectedCurl)
    }

    func testFileUploadCURL() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }
        
        let components = HTTPRequestComponents(
            url: URL(string: "https://example.com/upload")!,
            method: .post,
            headers: [.contentType: "text/plain"],
            body: .file(tempFile))
        
        let expectedCurl = """
        curl 'https://example.com/upload' \
            -X POST \
            -H 'Content-Type: text/plain' \
            --data-binary @'\(tempFile.path)'
        """
        
        XCTAssertEqual(components.curl, expectedCurl)
    }
}
