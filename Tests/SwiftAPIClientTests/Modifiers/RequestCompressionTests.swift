#if canImport(zlib)
import Foundation
@testable import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class APIClientCompressionTests: XCTestCase {

	@available(macOS 10.15, iOS 13, tvOS 13, watchOS 6, *)
	func testThatRequestCompressorProperlyCalculatesAdler32() async throws {
		let client = APIClient.test.compressRequest()
		let body: Data = try await client
			.post
			.body(Data([0]))
			.httpTest { request, _ in
                request.body!.data!
			}
		// From https://en.wikipedia.org/wiki/Adler-32
		XCTAssertEqual(body, Data([0x78, 0x5E, 0x63, 0x00, 0x00, 0x00, 0x01, 0x00, 0x01]))
	}
}
#endif
