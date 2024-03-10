import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class ErrorDecodingTests: XCTestCase {

	func testErrorDecoding() throws {
		let errorJSON = Data(#"{"error": "test_error"}"#.utf8)
		do {
			let _ = try APIClient(baseURL: URL(string: "https://example.com")!)
				.errorDecoder(.decodable(ErrorResponse.self))
				.call(.mock(errorJSON), as: .decodable(FakeResponse.self))
			XCTFail()
		} catch {
			XCTAssertEqual(error.localizedDescription, "test_error")
		}
	}
}

struct FakeResponse: Codable {

	let anyValue: String
}

struct ErrorResponse: Codable, LocalizedError {

	var error: String?
	var errorDescription: String? { error }
}
