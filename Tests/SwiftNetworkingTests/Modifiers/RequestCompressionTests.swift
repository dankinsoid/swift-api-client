
#if canImport(zlib)
import Foundation
@testable import SwiftNetworking
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class NetworkClientCompressionTests: XCTestCase {

	@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
	func testThatRequestCompressorProperlyCalculatesAdler32() throws {
		let client = NetworkClient(baseURL: URL(string: "https://example.com")!).compressRequest()
		let request = try client.body(Data("Wikipedia".utf8)).request()
		// From https://en.wikipedia.org/wiki/Adler-32
		XCTAssertEqual(request.httpBody, Data([87, 105, 107, 105, 112, 101, 100, 105, 97]))
	}
}
#endif
