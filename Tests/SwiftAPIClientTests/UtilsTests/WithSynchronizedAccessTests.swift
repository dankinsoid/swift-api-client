import Foundation
@testable import SwiftAPIClient
import XCTest

final class WithSynchronizedAccessTests: XCTestCase {

	// MARK: - Sanity

	func test_singleCaller_returnsValue() async throws {
		let id = UUID().uuidString
		let value = try await withThrowingSynchronizedAccess(id: id) {
			try await Task.sleep(nanoseconds: 10_000_000) // 10ms
			return 42
		}
		XCTAssertEqual(value, 42)
	}

	func test_secondCaller_sharesResultOfFirst() async throws {
		let id = UUID().uuidString
		let executions = ActorCounter()

		async let first = withThrowingSynchronizedAccess(id: id) {
			await executions.increment()
			try await Task.sleep(nanoseconds: 100_000_000) // 100ms
			return "result"
		}

		// Give first task time to register in Barriers
		try await Task.sleep(nanoseconds: 20_000_000) // 20ms

		async let second = withThrowingSynchronizedAccess(id: id) {
			await executions.increment()
			return "should-not-run"
		}

		let r1 = try await first
		let r2 = try await second

		XCTAssertEqual(r1, "result")
		XCTAssertEqual(r2, "result")
		let count = await executions.value
		XCTAssertEqual(count, 1, "Inner closure must run exactly once across waiters")
	}

	// MARK: - Cancellation: single caller (the one that started the shared task)

	/// When the only caller of `withThrowingSynchronizedAccess` is cancelled, the inner sleep
	/// must be interrupted and the call must throw `CancellationError`.
	func test_singleCaller_cancellation_propagatesToInnerSleep() async throws {
		let id = UUID().uuidString
		let innerCancelled = ActorFlag()
		let started = ActorFlag()

		let outer = Task {
			try await withThrowingSynchronizedAccess(id: id) {
				await started.set(true)
				do {
					try await Task.sleep(nanoseconds: 5_000_000_000) // 5s
					return "completed"
				} catch is CancellationError {
					await innerCancelled.set(true)
					throw CancellationError()
				}
			}
		}

		// Wait for inner work to start
		while await !started.value {
			try await Task.sleep(nanoseconds: 5_000_000)
		}

		outer.cancel()

		do {
			_ = try await outer.value
			XCTFail("Expected CancellationError")
		} catch is CancellationError {
			// expected
		} catch {
			XCTFail("Expected CancellationError, got \(error)")
		}

		// `release` triggers `task.cancel()` synchronously inside the actor, but the inner
		// `Task.sleep` observes that cancellation on its own scheduling step. Wait briefly
		// for the inner closure's catch branch to set the flag.
		let deadline = Date().addingTimeInterval(1.0)
		while await !innerCancelled.value, Date() < deadline {
			try await Task.sleep(nanoseconds: 5_000_000)
		}

		let cancelled = await innerCancelled.value
		XCTAssertTrue(cancelled, "Inner Task.sleep must observe cancellation when the caller is cancelled")
	}

	// MARK: - Cancellation: two waiters on the same id

	/// When two callers wait on the same id and only ONE of them is cancelled,
	/// the other waiter must still receive the result (or at least not be cancelled by association).
	func test_twoWaiters_oneCancelled_otherKeepsRunning() async throws {
		let id = UUID().uuidString
		let executions = ActorCounter()
		let firstStarted = ActorFlag()

		// First caller — starts the shared task
		let firstTask = Task {
			try await withThrowingSynchronizedAccess(id: id) {
				await executions.increment()
				await firstStarted.set(true)
				try await Task.sleep(nanoseconds: 300_000_000) // 300ms
				return "value"
			}
		}

		// Wait until shared task is registered & running
		while await !firstStarted.value {
			try await Task.sleep(nanoseconds: 5_000_000)
		}

		// Second caller — joins as a waiter
		let secondTask = Task {
			try await withThrowingSynchronizedAccess(id: id) {
				await executions.increment()
				return "should-not-run"
			}
		}

		// Give second a moment to actually start awaiting
		try await Task.sleep(nanoseconds: 30_000_000) // 30ms

		// Cancel ONLY the first waiter
		firstTask.cancel()

		// First should throw CancellationError
		do {
			_ = try await firstTask.value
			XCTFail("Expected first task to be cancelled")
		} catch is CancellationError {
			// expected
		} catch {
			// Some inner errors may also count; but for this test we expect cancellation
			XCTAssertTrue(error is CancellationError, "Expected CancellationError, got \(error)")
		}

		// Second waiter should still complete with a value (this is the point of the test)
		do {
			let result = try await secondTask.value
			XCTAssertEqual(result, "value", "Second waiter must not be cancelled by association")
		} catch {
			XCTFail("Second waiter was cancelled by association: \(error)")
		}

		let count = await executions.value
		XCTAssertEqual(count, 1, "Inner closure must run exactly once even when one waiter is cancelled")
	}

	/// When BOTH waiters are cancelled, both should observe `CancellationError`,
	/// and the inner sleep must be interrupted (no orphan work running 5s after the test).
	func test_twoWaiters_bothCancelled_innerWorkStops() async throws {
		let id = UUID().uuidString
		let started = ActorFlag()
		let innerCancelled = ActorFlag()

		let firstTask = Task {
			try await withThrowingSynchronizedAccess(id: id) {
				await started.set(true)
				do {
					try await Task.sleep(nanoseconds: 5_000_000_000) // 5s
					return "completed"
				} catch is CancellationError {
					await innerCancelled.set(true)
					throw CancellationError()
				}
			}
		}

		while await !started.value {
			try await Task.sleep(nanoseconds: 5_000_000)
		}

		let secondTask = Task {
			try await withThrowingSynchronizedAccess(id: id) {
				return "should-not-run"
			}
		}

		try await Task.sleep(nanoseconds: 30_000_000)

		firstTask.cancel()
		secondTask.cancel()

		_ = try? await firstTask.value
		_ = try? await secondTask.value

		// Give cancellation propagation a brief moment
		try await Task.sleep(nanoseconds: 100_000_000)

		let cancelled = await innerCancelled.value
		XCTAssertTrue(cancelled, "When all waiters are cancelled, inner work should also be cancelled")
	}
}

// MARK: - Test helpers

private actor ActorFlag {

	private var _value = false

	var value: Bool { _value }

	func set(_ v: Bool) { _value = v }
}

private actor ActorCounter {

	private var _value = 0

	var value: Int { _value }

	func increment() { _value += 1 }
}
