import Foundation
@testable import SwiftAPIClient
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class QueryParameterMiddlewareTests: XCTestCase {

    let baseClient = APIClient(string: "https://example.com")
        .usingMocks(policy: .ignore)
        .loggingComponents(.full)
        .httpClient(.test())
        .configs(\.testHTTPClient) { components, _ in
            (components.url!.absoluteString.data(using: .utf8)!, HTTPResponse(status: .ok))
        }

    let serializer = Serializer<Data, String>.string.map { string in URL(string: string)! }

    func testAddsParameterWhenMissing() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: ["api_key": "test123"])

        let client = baseClient.httpClientMiddleware(middleware)
        let url = try await client.call(.http, as: serializer)

        XCTAssertNotNil(url)
        XCTAssertEqual(url.query, "api_key=test123")
    }

    func testDoesNotAddParameterWhenPresent() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: ["api_key": "test123"])
        let client = baseClient
            .query("api_key", "existing_key")
            .httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)

        XCTAssertEqual(url.query, "api_key=existing_key")
    }

    func testAddsMultipleParametersWhenMissing() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: [
            "api_key": "test123",
            "version": "v1",
            "format": "json",
        ])
        let client = baseClient.httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        XCTAssertEqual(queryItems.count, 3)
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "api_key", value: "test123")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "version", value: "v1")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "format", value: "json")))
    }

    func testAddsOnlyMissingParameters() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: [
            "api_key": "test123",
            "version": "v1",
            "format": "json",
        ])
        let client = baseClient
            .query("version", "v2")
            .httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        XCTAssertEqual(queryItems.count, 3)
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "api_key", value: "test123")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "version", value: "v2")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "format", value: "json")))
    }

    func testWorksWithEmptyDefaults() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: [:])
        let client = baseClient
            .query("test", "value")
            .httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)

        XCTAssertEqual(url.query, "test=value")
    }

    func testWorksWithNoExistingQuery() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: ["api_key": "test123"])
        let client = baseClient.httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)

        XCTAssertEqual(url.query, "api_key=test123")
    }

    func testWorksWithExistingPath() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: ["api_key": "test123"])
        let client = baseClient
            .path("users", "123")
            .httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)

        XCTAssertEqual(url.absoluteString, "https://example.com/users/123?api_key=test123")
    }

    func testPreservesParameterOrdering() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: [
            "api_key": "test123",
            "version": "v1",
        ])
        let client = baseClient
            .query("existing", "first")
            .httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        // Existing parameters should come first
        XCTAssertEqual(queryItems.first?.name, "existing")
        XCTAssertEqual(queryItems.first?.value, "first")

        // New parameters should be added after
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "api_key", value: "test123")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "version", value: "v1")))
    }

    func testHandlesSpecialCharactersInValues() async throws {
        let middleware = QueryParameterMiddleware(defaultParameters: [
            "special": "value with spaces & symbols",
            "emoji": "test ❤️",
        ])
        let client = baseClient.httpClientMiddleware(middleware)

        let url = try await client.call(.http, as: serializer)
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "special", value: "value with spaces & symbols")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "emoji", value: "test ❤️")))
    }

    func testWorksWithMultipleMiddleware() async throws {
        let middleware1 = QueryParameterMiddleware(defaultParameters: ["api_key": "test123"])
        let middleware2 = QueryParameterMiddleware(defaultParameters: ["version": "v1"])

        let client = baseClient
            .httpClientMiddleware(middleware1)
            .httpClientMiddleware(middleware2)

        let url = try await client.call(.http, as: serializer)
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems ?? []

        XCTAssertEqual(queryItems.count, 2)
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "api_key", value: "test123")))
        XCTAssertTrue(queryItems.contains(URLQueryItem(name: "version", value: "v1")))
    }
}
