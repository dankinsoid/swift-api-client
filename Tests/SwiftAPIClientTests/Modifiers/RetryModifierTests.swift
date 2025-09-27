import Foundation
@testable import SwiftAPIClient
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RetryModifierTests: XCTestCase {

	let client = APIClient(baseURL: URL(string: "https://example.com")!)

	func testRetryWithLimit() async throws {
		var attempts = 0

		let client = client.retry(limit: 2, interval: 0)

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 3) // Initial attempt + 2 retries
		}
	}

	func testRetryWithoutLimit() async throws {
		var attempts = 0
		let maxAttempts = 5

		let client = client.retry(limit: nil, interval: 0)

		do {
			try await client.httpTest { _, _ -> Data in
				attempts += 1
				if attempts < maxAttempts {
					throw URLError(.networkConnectionLost)
				}
				return Data()
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, maxAttempts)
	}

	func testRetryInterval() async throws {
		let startTime = Date()
		var attempts = 0
		let interval: TimeInterval = 0.1

		let client = client.retry(limit: 2, interval: interval)

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			let elapsed = Date().timeIntervalSince(startTime)
			XCTAssertGreaterThanOrEqual(elapsed, interval * 2) // 2 retry intervals
			XCTAssertEqual(attempts, 3)
		}
	}

	func testRetryWithDynamicInterval() async throws {
		let startTime = Date()
		var attempts = 0

		let client = client.retry(limit: 2, interval: { retryCount in
			return TimeInterval(retryCount + 1) * 0.05 // 0.05, 0.1
		})

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			let elapsed = Date().timeIntervalSince(startTime)
			XCTAssertGreaterThanOrEqual(elapsed, 0.15) // 0.05 + 0.1
			XCTAssertEqual(attempts, 3)
		}
	}

	func testRetryRequestFailedCondition() async throws {
		var attempts = 0

		let client = client.retry(when: .requestFailed, limit: 2, interval: 0)

		// Test with network error (should retry)
		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 3)
		}

		attempts = 0

		// Test with 500 error (should retry for safe methods)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3) // Should retry on error status
	}

	func testRetryStatusCodesCondition() async throws {
		var attempts = 0

		let client = client.retry(when: .statusCodes(.tooManyRequests, .internalServerError), limit: 2, interval: 0)

		// Test with 429 status (should retry)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// Test with 404 status (should not retry)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .notFound))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testRetryMethodsCondition() async throws {
		var getAttempts = 0
		var postAttempts = 0

		let client = client.retry(when: .methods(.get), limit: 2, interval: 0)

		// Test GET request (should retry)
		do {
			try await client.httpTest { request, _ -> Data in
				if request.method == .get {
					getAttempts += 1
					throw URLError(.networkConnectionLost)
				}
				return Data()
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(getAttempts, 3)
		}

		// Test POST request (should not retry)
		do {
			try await client.method(.post).httpTest { request, _ -> Data in
				if request.method == .post {
					postAttempts += 1
					throw URLError(.networkConnectionLost)
				}
				return Data()
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(postAttempts, 1)
		}
	}

	func testRetryConditionAnd() async throws {
		var attempts = 0

		let condition = RetryRequestCondition.methods(.get).and(.statusCodes(.internalServerError))
		let client = client.retry(when: condition, limit: 2, interval: 0)

		// Test GET + 500 (should retry)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// Test GET + 404 (should not retry - wrong status)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .notFound))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testRetryConditionOr() async throws {
		var attempts = 0

		let condition = RetryRequestCondition.statusCodes(.tooManyRequests).or(.statusCodes(.internalServerError))
		let client = client.retry(when: condition, limit: 2, interval: 0)

		// Test 429 (should retry)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// Test 500 (should retry)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3)
	}

	func testRateLimitExceededCondition() async throws {
		var attempts = 0

		let client = client.retry(when: .rateLimitExceeded, limit: 2, interval: 0)

		// Test 429 with GET (should retry)
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// Test 429 with POST (should not retry - unsafe method)
		do {
			try await client.method(.post).httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testRetryWithCancellationError() async throws {
		var attempts = 0

		let client = client.retry(when: .requestFailed, limit: 2, interval: 0)

		// Test with cancellation error (should not retry)
		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw CancellationError()
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 1)
		}
	}

	func testRetryKey() async throws {
		var hostAAttempts = 0
		var hostBAttempts = 0

		let client = client.retry(
			retryKey: { request in
				return request.url?.host ?? "unknown"
			},
			when: .requestFailed,
			limit: 2,
			interval: 0.1
		)

		// Start concurrent requests to different hosts
		async let hostATask: Void = {
			do {
				try await client.url(URL(string: "https://host-a.com")!).httpTest { _, _ -> Void in
					hostAAttempts += 1
					throw URLError(.networkConnectionLost)
				}
			} catch {
				// Expected
			}
		}()

		async let hostBTask: Void = {
			do {
				try await client.url(URL(string: "https://host-b.com")!).httpTest { _, _ -> Void in
					hostBAttempts += 1
					throw URLError(.networkConnectionLost)
				}
			} catch {
				// Expected
			}
		}()

		_ = await (hostATask, hostBTask)

		// Both should have retried independently
		XCTAssertEqual(hostAAttempts, 3)
		XCTAssertEqual(hostBAttempts, 3)
	}

	func testRetrySuccessAfterFailures() async throws {
		var attempts = 0

		let client = client.retry(when: .requestFailed, limit: 5, interval: 0)

		do {
			try await client.httpTest { _, _ -> Data in
				attempts += 1
				if attempts < 3 {
					throw URLError(.networkConnectionLost)
				}
				return Data()
			}
		} catch {
			XCTFail("Should not throw error")
		}

		XCTAssertEqual(attempts, 3)
	}

	func testCustomRetryCondition() async throws {
		var retryAttempts = 0
		var noRetryAttempts = 0

		let customCondition = RetryRequestCondition { request, result, _ in
			// Only retry if the URL path contains "retry" but not "no-retry"
			guard let url = request.url,
				  url.absoluteString.contains("/retry") && !url.absoluteString.contains("/no-retry") else {
				return false
			}

			switch result {
			case .success:
				return false
			case .failure:
				return true
			}
		}

		let client = client.retry(when: customCondition, limit: 2, interval: 0)

		// Test with URL containing "retry" (should retry)
		do {
			try await client.url(URL(string: "https://example.com/retry")!).httpTest { _, _ -> Void in
				retryAttempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(retryAttempts, 3)
		}

		// Test with URL not containing "retry" (should not retry)
		do {
			try await client.url(URL(string: "https://example.com/no-retry")!).httpTest { _, _ -> Void in
				noRetryAttempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(noRetryAttempts, 1)
		}
	}
}