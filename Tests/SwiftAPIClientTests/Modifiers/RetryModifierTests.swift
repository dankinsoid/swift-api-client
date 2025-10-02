import Foundation
@testable import SwiftAPIClient
import XCTest
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class RetryModifierTests: XCTestCase {

	let client = APIClient(baseURL: URL(string: "https://example.com")!)
		.retryInterval(0)

	// MARK: - Basic Retry Tests

	func testDefaultRetryCondition() async throws {
		var attempts = 0
		let client = client.retry()

		// Should retry GET on network error
		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 6) // 1 initial + 5 retries (default limit)
		}
	}

	func testRetryLimit() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryLimit(3)

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 4) // Retries up to limit (1 initial + retries)
		}
	}

	func testRetryLimitNil() async throws {
		var attempts = 0
		let maxAttempts = 10
		let client = client
			.retryLimit(nil)
			.retry()

		do {
			try await client.httpTest { _, _ -> Data in
				attempts += 1
				if attempts < maxAttempts {
					throw URLError(.networkConnectionLost)
				}
				return Data()
			}
		} catch {
			XCTFail("Should not throw \(error)")
		}

		XCTAssertEqual(attempts, maxAttempts)
	}

	// MARK: - Interval Tests

	func testFixedRetryInterval() async throws {
		let startTime = Date()
		var attempts = 0
		let interval: TimeInterval = 0.1

		let client = client
			.retry()
			.retryLimit(2)
			.retryInterval(interval)

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			let elapsed = Date().timeIntervalSince(startTime)
			XCTAssertGreaterThanOrEqual(elapsed, interval * 2)
			XCTAssertEqual(attempts, 3)
		}
	}

	func testDynamicRetryInterval() async throws {
		let startTime = Date()
		var attempts = 0

		let client = client
			.retry()
			.retryLimit(2)
			.retryInterval { attempt, _ in
				TimeInterval(attempt + 1) * 0.05
			}

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

	func testExponentialBackoff() async throws {
		var attempts = 0
		var intervals: [TimeInterval] = []

		let client = client
			.retry()
			.retryLimit(3)
			.retryInterval { attempt, _ in
				let interval = min(0.01 * pow(2.0, Double(attempt)), 1.0)
				intervals.append(interval)
				return interval
			}

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 4)
			XCTAssertEqual(intervals, [0.01, 0.02, 0.04])
		}
	}

	// MARK: - Retry Condition Tests

	func testRequestFailedCondition() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.requestFailed)
			.retryLimit(2)

		// Network error - should retry
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

		// Successful response - should not retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .ok))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testRequestMethodIsSafeCondition() async throws {
		var getAttempts = 0
		var postAttempts = 0

		let client = client
			.retry()
			.retryCondition(.requestMethodIsSafe)
			.retryLimit(2)
			.retryInterval(0)

		// GET (safe) - should retry
		do {
			try await client.httpTest { _, _ -> Void in
				getAttempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(getAttempts, 3)
		}

		// POST (unsafe) - should not retry
		do {
			try await client.method(.post).httpTest { _, _ -> Void in
				postAttempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(postAttempts, 1)
		}
	}

	func testStatusCodesCondition() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.statusCodes(.tooManyRequests, .internalServerError))
			.retryLimit(2)
			.retryInterval(0)

		// 429 - should retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// 404 - should not retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .notFound))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testMethodsCondition() async throws {
		var getAttempts = 0
		var postAttempts = 0

		let client = client
			.retry()
			.retryCondition(.methods(.get, .put))
			.retryLimit(2)
			.retryInterval(0)

		// GET - should retry
		do {
			try await client.httpTest { _, _ -> Void in
				getAttempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(getAttempts, 3)
		}

		// POST - should not retry
		do {
			try await client.method(.post).httpTest { _, _ -> Void in
				postAttempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(postAttempts, 1)
		}
	}

	func testRateLimitExceededCondition() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.rateLimitExceeded)
			.retryLimit(2)
			.retryInterval(0)

		// 429 - should retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// 500 - should not retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)
	}

	// MARK: - Condition Composition Tests

	func testAndCondition() async throws {
		var attempts = 0
		let condition = RetryRequestCondition.methods(.get).and(.statusCodes(.internalServerError))
		let client = client
			.retry()
			.retryCondition(condition)
			.retryLimit(2)
			.retryInterval(0)

		// GET + 500 - should retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// GET + 404 - should not retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .notFound))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)

		attempts = 0

		// POST + 500 - should not retry
		do {
			try await client.method(.post).httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testOrCondition() async throws {
		var attempts = 0
		let condition = RetryRequestCondition.statusCodes(.tooManyRequests).or(.statusCodes(.serviceUnavailable))
		let client = client
			.retry()
			.retryCondition(condition)
			.retryLimit(2)
			.retryInterval(0)

		// 429 - should retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .tooManyRequests))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// 503 - should retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .serviceUnavailable))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// 500 - should not retry
		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .internalServerError))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)
	}

	func testComplexConditions() async throws {
		var attempts = 0
		let condition = RetryRequestCondition.and(
			.methods(.get, .post),
			.or(
				.requestFailed,
				.statusCodes(.serviceUnavailable)
			)
		)

		let client = client
			.retry()
			.retryCondition(condition)
			.retryLimit(2)
			.retryInterval(0)

		// GET + network error - should retry
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

		// POST + 503 - should retry
		do {
			try await client.method(.post).httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .serviceUnavailable))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)

		attempts = 0

		// DELETE + 503 - should not retry (wrong method)
		do {
			try await client.method(.delete).httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				return (Data(), HTTPResponse(status: .serviceUnavailable))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 1)
	}

	// MARK: - Cancellation Tests

	func testCancellationNotRetried() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.requestFailed)
			.retryLimit(3)
			.retryInterval(0)

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw CancellationError()
			}
			XCTFail("Expected error")
		} catch is CancellationError {
			XCTAssertEqual(attempts, 1)
		} catch {
			XCTFail("Wrong error type")
		}
	}

	// MARK: - Success After Failure Tests

	func testSuccessAfterRetries() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryLimit(5)
			.retryInterval(0)

		do {
			try await client.httpTest { _, _ -> Data in
				attempts += 1
				if attempts < 3 {
					throw URLError(.networkConnectionLost)
				}
				return Data()
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 3)
	}

	func testSuccessAfterStatusCodeRetries() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.statusCodes(.serviceUnavailable))
			.retryLimit(5)
			.retryInterval(0)

		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				if attempts < 4 {
					return (Data(), HTTPResponse(status: .serviceUnavailable))
				}
				return (Data(), HTTPResponse(status: .ok))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 4)
	}

	// MARK: - Retry-After Header Tests

	func testRetryAfterHeaderSeconds() async throws {
		let startTime = Date()
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.statusCodes(.tooManyRequests))
			.retryLimit(1)
			.retryInterval(0)

		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				if attempts == 1 {
					var response = HTTPResponse(status: .tooManyRequests)
					response.headerFields[.retryAfter] = "1"
					return (Data(), response)
				}
				return (Data(), HTTPResponse(status: .ok))
			}
		} catch {
			XCTFail("Should not throw")
		}

		let elapsed = Date().timeIntervalSince(startTime)
		XCTAssertEqual(attempts, 2)
		XCTAssertGreaterThanOrEqual(elapsed, 1.0)
	}

	func testRetryAfterOnlyForConfiguredStatusCodes() async throws {
		var attempts = 0
		let client = client
			.retry()
			.retryCondition(.statusCodes(.internalServerError))
			.retryLimit(1)
			.retryInterval(0.05)
			.configs(\.retryAfterHeaderStatusCodes, [.tooManyRequests]) // Only 429

		let startTime = Date()

		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				if attempts == 1 {
					var response = HTTPResponse(status: .internalServerError)
					response.headerFields[.retryAfter] = "5" // Should be ignored
					return (Data(), response)
				}
				return (Data(), HTTPResponse(status: .ok))
			}
		} catch {
			XCTFail("Should not throw")
		}

		let elapsed = Date().timeIntervalSince(startTime)
		XCTAssertEqual(attempts, 2)
		XCTAssertLessThan(elapsed, 1.0) // Should use regular interval, not Retry-After
	}

	// MARK: - Global Backoff Tests

	func testGlobalBackoffSynchronization() async throws {
		actor RequestTracker {
			var request1Attempts = 0
			var request2Attempts = 0
			var request1Times: [Date] = []
			var request2Times: [Date] = []

			func incrementRequest1() -> Int {
				request1Attempts += 1
				request1Times.append(Date())
				return request1Attempts
			}

			func incrementRequest2() {
				request2Attempts += 1
				request2Times.append(Date())
			}

			func getRequest1Attempts() -> Int { request1Attempts }
			func getRequest2Attempts() -> Int { request2Attempts }
			func getRequest1Times() -> [Date] { request1Times }
			func getRequest2Times() -> [Date] { request2Times }
		}

		let tracker = RequestTracker()

		let client = client
			.retry()
			.retryCondition(.statusCodes(.tooManyRequests))
			.retryLimit(2)
			.retryInterval(0.1)

		async let task1: Void = {
			do {
				try await client.httpTest { _, _ -> (Data, HTTPResponse) in
					let attempts = await tracker.incrementRequest1()
					if attempts == 1 {
						return (Data(), HTTPResponse(status: .tooManyRequests))
					}
					return (Data(), HTTPResponse(status: .ok))
				}
			} catch {
				XCTFail("Should not throw")
			}
		}()

		// Start second request slightly after first
		try await Task.sleep(nanoseconds: 10_000_000) // 10ms

		async let task2: Void = {
			do {
				try await client.httpTest { _, _ -> (Data, HTTPResponse) in
					await tracker.incrementRequest2()
					return (Data(), HTTPResponse(status: .ok))
				}
			} catch {
				XCTFail("Should not throw")
			}
		}()

		_ = await (task1, task2)

		let request1Attempts = await tracker.getRequest1Attempts()
		let request2Attempts = await tracker.getRequest2Attempts()
		XCTAssertEqual(request1Attempts, 2)
		XCTAssertEqual(request2Attempts, 1)

		// Request 2 should wait for request 1's backoff
		let request1Times = await tracker.getRequest1Times()
		let request2Times = await tracker.getRequest2Times()
		if request1Times.count >= 2 && request2Times.count >= 1 {
			let backoffEnd = request1Times[1]
			let request2Start = request2Times[0]
			XCTAssertGreaterThanOrEqual(request2Start, backoffEnd)
		}
	}

	func testCustomBackoffPolicy() async throws {
		var attempts = 0
		let customPolicy = RetryBackoffPolicy(
			scopeHash: { request in
				request.urlComponents.path
			},
			isGlobalBackoff: { _, response in
				response.status == .tooManyRequests
			}
		)

		let client = client
			.retry()
			.retryBackoffPolicy(customPolicy)
			.retryCondition(.statusCodes(.tooManyRequests))
			.retryLimit(1)
			.retryInterval(0.05)

		do {
			try await client.path("test").httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				if attempts == 1 {
					return (Data(), HTTPResponse(status: .tooManyRequests))
				}
				return (Data(), HTTPResponse(status: .ok))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 2)
	}

	func testNoBackoffWhenPolicyReturnsNil() async throws {
		var attempts = 0
		let noScopePolicy = RetryBackoffPolicy(
			scopeHash: { _ in nil },
			isGlobalBackoff: { _, _ in true }
		)

		let client = client
			.retry()
			.retryBackoffPolicy(noScopePolicy)
			.retryCondition(.statusCodes(.tooManyRequests))
			.retryLimit(1)
			.retryInterval(0)

		do {
			try await client.httpTest { _, _ -> (Data, HTTPResponse) in
				attempts += 1
				if attempts == 1 {
					return (Data(), HTTPResponse(status: .tooManyRequests))
				}
				return (Data(), HTTPResponse(status: .ok))
			}
		} catch {
			XCTFail("Should not throw")
		}

		XCTAssertEqual(attempts, 2)
	}

	// MARK: - Custom Retry Condition Tests

	func testCustomRetryCondition() async throws {
		var attempts = 0
		let customCondition = RetryRequestCondition { request, response, error, _ in
			// Only retry if path contains "retry"
			guard request.urlComponents.path.contains("retry") else {
				return false
			}
			return error != nil || response?.status.kind.isError == true
		}

		let client = client
			.retry()
			.retryCondition(customCondition)
			.retryLimit(2)
			.retryInterval(0)

		// Path with "retry" - should retry
		do {
			try await client.path("api/retry/endpoint").httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 3)
		}

		attempts = 0

		// Path without "retry" - should not retry
		do {
			try await client.path("api/endpoint").httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			XCTAssertEqual(attempts, 1)
		}
	}

	// MARK: - Jitter Tests

	func testJitterConfiguration() async throws {
		var attempts = 0
		let jitterConfig = RetryJitterConfigs(
			fraction: 0.0...0.0, // No jitter for predictable testing
			minNs: 0,
			maxNs: 0
		)

		let client = client
			.retry()
			.configs(\.retryJitterConfigs, jitterConfig)
			.retryLimit(1)
			.retryInterval(0.1)

		let startTime = Date()

		do {
			try await client.httpTest { _, _ -> Void in
				attempts += 1
				throw URLError(.networkConnectionLost)
			}
			XCTFail("Expected error")
		} catch {
			let elapsed = Date().timeIntervalSince(startTime)
			XCTAssertEqual(attempts, 2)
			// With no jitter, should be close to exact interval
			XCTAssertGreaterThanOrEqual(elapsed, 0.1)
			XCTAssertLessThan(elapsed, 0.15)
		}
	}
}
