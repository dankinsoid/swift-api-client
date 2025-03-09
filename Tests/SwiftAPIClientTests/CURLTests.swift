import XCTest

@testable import SwiftAPIClient

final class CURLTests: XCTestCase {

    func testBasicGETRequest() throws {
        let cURL = """
            curl 'https://example.com/api/v1/users' \
                -X GET \
                -H 'Accept: application/json'
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .get)
        XCTAssertEqual(components.headers[.accept], "application/json")
        XCTAssertNil(components.body)

        // Test cURL string generation
        let generatedCurl = components.cURL
        XCTAssertTrue(generatedCurl.contains("curl \"https://example.com/api/v1/users\""))
        XCTAssertTrue(generatedCurl.contains("-H \"Accept: application/json\""))
    }

    func testPOSTRequestWithBody() throws {
        let cURL = """
            curl 'https://example.com/api/v1/users' \
                -X POST \
                -H 'Content-Type: application/json' \
                -d '{"name":"John","age":30}'
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .post)
        XCTAssertEqual(components.headers[.contentType], "application/json")

        switch components.body {
        case let .data(data):
            let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(body?["name"] as? String, "John")
            XCTAssertEqual(body?["age"] as? Int, 30)
        default:
            XCTFail("Expected data body")
        }
    }

    func testRequestWithMultipleHeaders() throws {
        let cURL = """
            curl 'https://example.com/api/v1/users' \
                -X GET \
                -H 'Accept: application/json' \
                -H 'Authorization: Bearer token123'
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.headers[.accept], "application/json")
        XCTAssertEqual(components.headers[.authorization], "Bearer token123")
    }

    func testInvalidCURLCommand() {
        let invalidCurl = "invalid cURL command"

        XCTAssertThrowsError(try HTTPRequestComponents(cURL: invalidCurl))
    }

    func testCURLStringGeneration() throws {
        let components = try HTTPRequestComponents(
            url: URL(string: "https://example.com/api/v1/users")!,
            method: .post,
            headers: [
                .contentType: "application/json",
                .accept: "application/json",
            ],
            body: .data(JSONSerialization.data(withJSONObject: ["name": "John"]))
        )

        let expectedCurl = """
            curl "https://example.com/api/v1/users" \\
                -X POST \\
                -H "Content-Type: application/json" \\
                -H "Accept: application/json" \\
                -d "{\\"name\\":\\"John\\"}"
            """

        XCTAssertEqual(components.cURL, expectedCurl)
    }

    func testFileUploadCURL() throws {
        let tempFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
        try "Test content".write(to: tempFile, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: tempFile) }

        let components = HTTPRequestComponents(
            url: URL(string: "https://example.com/upload")!,
            method: .post,
            headers: [.contentType: "text/plain"],
            body: .file(tempFile)
        )

        let expectedCurl = """
            curl "https://example.com/upload" \\
                -X POST \\
                -H "Content-Type: text/plain" \\
                --data-binary @"\(tempFile.path)"
            """

        XCTAssertEqual(components.cURL, expectedCurl)
    }
    func testGETRequestWithoutExplicitMethod() throws {
        let cURL = """
            curl 'https://example.com/api/v1/users' \
                -H 'Accept: application/json'
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .get)  // Default should be GET
        XCTAssertEqual(components.headers[.accept], "application/json")
        XCTAssertNil(components.body)
    }

    func testRequestWithDifferentHeaderFormatting() throws {
        let cURL = """
            curl "https://example.com/api/v1/users" \
                -H "Accept:application/json" \
                -H "Authorization:Bearer token123"
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.headers[.accept], "application/json")
        XCTAssertEqual(components.headers[.authorization], "Bearer token123")
    }

    func testPOSTRequestWithDifferentFormatting() throws {
        let cURL = """
            curl "https://example.com/api/v1/users" -XPOST -H "Content-Type: application/json" -d '{"name":"Alice"}'
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .post)
        XCTAssertEqual(components.headers[.contentType], "application/json")

        switch components.body {
        case let .data(data):
            let body = try JSONSerialization.jsonObject(with: data) as? [String: Any]
            XCTAssertEqual(body?["name"] as? String, "Alice")
        default:
            XCTFail("Expected data body")
        }
    }

    func testPOSTRequestWithMultipleDataFlags() throws {
        let cURL = """
            curl 'https://example.com/api/v1/users' \
                -X POST \
                -H 'Content-Type: application/x-www-form-urlencoded' \
                -d 'name=John' \
                -d 'age=30'
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.method, .post)
        XCTAssertEqual(components.headers[.contentType], "application/x-www-form-urlencoded")

        switch components.body {
        case let .data(data):
            let bodyString = String(data: data, encoding: .utf8)
            XCTAssertEqual(bodyString, "name=John&age=30")  // Ensure concatenation of multiple -d flags
        default:
            XCTFail("Expected data body")
        }
    }

    func testCURLWithDifferentOptionOrder() throws {
        let cURL = """
            curl -H "Accept: application/json" -X GET "https://example.com/api/v1/users"
            """

        let components = try HTTPRequestComponents(cURL: cURL)

        XCTAssertEqual(components.url?.absoluteString, "https://example.com/api/v1/users")
        XCTAssertEqual(components.method, .get)
        XCTAssertEqual(components.headers[.accept], "application/json")
    }
}
