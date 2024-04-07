import Foundation
@testable import SwiftAPIClient
import XCTest

@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
class WithTimeoutTests: XCTestCase {

    func test_withTimeout_fast() async throws {
        let result = try await withTimeout(1) { 42 }
        XCTAssertEqual(result, 42)
    }

    func test_withTimeout_zero_interval() async {
        do {
            _ = try await withTimeout(0) { 42 }
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }

    func test_withTimeout_timeout() async {
        do {
            _ = try await withTimeout(.nanoseconds(2)) {
                try await Task.sleep(for: .milliseconds(4))
                return 42
            }
            XCTFail("Expected timeout error")
        } catch {
            XCTAssertTrue(error is TimeoutError)
        }
    }

    func test_withTimeout_success() async throws {
        _ = try await withTimeout(.milliseconds(4)) {
            try await Task.sleep(for: .nanoseconds(2))
            return 42
        }
    }
}
