import Foundation

/// Executes a given task with synchronization based on a unique identifier, ensuring serialized access to potentially shared resources.
/// This function is designed for tasks that may throw errors, allowing for error propagation. It works in conjunction with `waitForThrowingSynchronizedAccess`
/// to facilitate scenarios where it's crucial to ensure that all error-prone synchronized tasks associated with the same identifier have been completed before proceeding.
///
/// - Parameters:
///   - id: A unique identifier for the synchronized task group. This ID is used to serialize access among tasks that interact with shared resources,
///         preventing race conditions and ensuring data integrity.
///   - task: The async task to be executed. This task is potentially error-prone and its execution is synchronized with others sharing the same identifier.
/// - Returns: The result of the executed task, if it is successfully completed and without throwing any errors.
/// - Throws: An error if the task execution fails. This allows for explicit error handling by the caller.
///
/// This function is ideal for operations that require both synchronization and error handling, such as modifying shared data where failure must be managed explicitly.
public func withThrowingSynchronizedAccess<T: Sendable, ID: Hashable & Sendable>(
	id taskIdentifier: ID,
	task: sending @escaping () async throws -> T
) async throws -> T {
	let operation = UncheckedSendableBox(task)
	let lease = await Barriers.shared.join(taskIdentifier) { try await operation.value() }
	let result: Any
	do {
		result = try await lease.task.wait()
	} catch {
		await Barriers.shared.release(lease)
		throw error
	}
	await Barriers.shared.release(lease)
	guard let typed = result as? T else {
		throw UnexpectedSharedTaskTypeError()
	}
	return typed
}

/// Executes a given task with synchronization based on a unique identifier, ensuring serialized access to potentially shared resources.
/// Unlike `withThrowingSynchronizedAccess`, this function does not propagate errors, making it suitable for tasks where errors are not expected
/// or are internally handled. It complements `withThrowingSynchronizedAccess` and `waitForSynchronizedAccess`, facilitating scenarios where it's
/// important to ensure that all synchronized tasks associated with the same identifier have completed, especially when such tasks do not involve
/// error handling by the caller.
///
/// - Parameters:
///   - id: A unique identifier for the synchronized task group. This ID is used to serialize access among tasks that interact with shared resources,
///         preventing race conditions and ensuring data integrity.
///   - task: The async task to be executed. Its execution is synchronized with others sharing the same identifier, but errors, if any, are not propagated.
/// - Returns: The result of the executed task. This version does not throw errors, assuming any necessary error handling is internal to the task.
///
/// Use this function for operations that require synchronization but do not need explicit error handling to be exposed to the caller, such as read-only
/// access to shared data where the outcomes are non-critical or are managed within the tasks themselves.
public func withSynchronizedAccess<T: Sendable, ID: Hashable & Sendable>(
	id taskIdentifier: ID,
	task: sending @escaping () async -> T
) async -> T {
	let operation = UncheckedSendableBox(task)
	while true {
		let lease = await Barriers.shared.join(taskIdentifier) { await operation.value() }
		// Not cancellable: the caller needs a value, and leaving early would cancel the operation for other callers.
		let result = await lease.task.outcome()
		await Barriers.shared.release(lease)
		if case let .success(value) = result, let typed = value as? T {
			return typed
		}
		// Joined another caller's operation that failed or returned another type; it has finished, so join again.
	}
}

/// Waits for the completion of all synchronized accesses associated with a specific identifier before proceeding.
/// This function is part of a set that includes `withThrowingSynchronizedAccess`, and it's used when you need to ensure
/// that all operations with potential errors associated with the given identifier have completed. It is suitable for
/// scenarios requiring strict error handling, complementing the `withThrowingSynchronizedAccess` function by providing
/// a mechanism to await all such accesses.
///
/// - Parameters:
///   - id: A unique identifier for the synchronized task group. This ID determines the group of tasks to wait for.
///     The identifier must conform to the `Hashable` protocol to ensure uniqueness.
///   - type: The type of the result to be returned.
/// - Returns: The result of the awaited task, if it completes successfully. If no task is found for the given identifier, `nil` is returned.
/// - Throws: Propagates errors from any of the awaited tasks within the same identifier group if they fail. This allows callers
///   to handle failures of synchronized tasks explicitly.
///
/// Use this function when you need to wait for the completion of all tasks associated with a specific identifier that might throw errors,
/// ensuring that any necessary error handling can be performed after all such tasks have completed. It is particularly useful in
/// scenarios where tasks modify or access shared resources and need to be executed or awaited serially to prevent data corruption or race conditions.
@discardableResult
public func waitForThrowingSynchronizedAccess<ID: Hashable & Sendable, T>(id taskIdentifier: ID, of type: T.Type = T.self) async throws -> T? {
	guard let lease = await Barriers.shared.retain(taskIdentifier) else {
		return nil
	}
	let result: Any
	do {
		result = try await lease.task.wait()
	} catch {
		await Barriers.shared.release(lease)
		throw error
	}
	await Barriers.shared.release(lease)
	guard let typed = result as? T else {
		throw UnexpectedSharedTaskTypeError()
	}
	return typed
}

/// Waits for the completion of all synchronized accesses associated with a specific identifier before proceeding.
/// This function complements `withSynchronizedAccess` by providing a non-throwing mechanism to await the completion
/// of all operations associated with the given identifier. It's suitable for scenarios where errors from the synchronized
/// tasks are either not expected or are handled internally, thus not requiring propagation to the caller.
///
/// - Parameters:
///   - id: A unique identifier for the synchronized task group. This ID determines the group of tasks to wait for.
///     The identifier must conform to the `Hashable` protocol to ensure uniqueness.
///   - type: The type of the result to be returned.
/// - Returns: The result of the awaited task, if it completes successfully. If no task is found for the given identifier, `nil` is returned.
///
/// Use this function when you need to ensure that all tasks associated with a specific identifier have completed, especially
/// in cases where tasks are accessing or modifying shared resources and need to be executed or awaited serially to maintain
/// consistency and prevent race conditions. It's ideal for scenarios where failure of the tasks is not critical to the caller
/// or where errors are handled within the tasks themselves.
@discardableResult
public func waitForSynchronizedAccess<ID: Hashable & Sendable, T>(id taskIdentifier: ID, of type: T.Type = T.self) async -> T? {
	guard let lease = await Barriers.shared.retain(taskIdentifier) else {
		return nil
	}
	let result = try? await lease.task.wait()
	await Barriers.shared.release(lease)
	return result as? T
}

/// Awaits the value of a shared unstructured `Task` while honoring the *caller's* cancellation
/// without affecting other awaiters of the same task.
///
/// `Task { ... }` doesn't inherit cancellation from its enclosing task, so a parent's
/// `Task.cancel()` never reaches the work inside. We also can't simply call `task.cancel()`
/// here, because the task is shared between several callers (e.g. parallel requests waiting
/// on the same backoff): cancelling it would synthesize a fake operation failure and
/// propagate `CancellationError` to every waiter.
///
/// Instead, this helper races two outcomes — the shared task's value vs. the caller's local
/// cancellation — and resolves with whichever comes first. The shared task keeps running for
/// the remaining waiters; only the cancelled caller throws `CancellationError`.
func awaitRespectingCancellation<T, E: Error>(_ task: Task<T, E>) async throws -> T {
	try Task.checkCancellation()
	let box = ContinuationBox<T>()
	return try await withTaskCancellationHandler {
		try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<T, Error>) in
			Task {
				await box.attach(continuation)
				do {
					let value = try await task.value
					await box.resume(.success(value))
				} catch {
					await box.resume(.failure(error))
				}
			}
		}
	} onCancel: {
		Task { await box.resume(.failure(CancellationError())) }
	}
}

/// Single-shot, thread-safe holder that delivers exactly one result to a `CheckedContinuation`.
/// Tolerates either order of arrival: continuation-then-result or result-then-continuation.
private final actor ContinuationBox<T> {

	private var continuation: CheckedContinuation<T, Error>?
	private var pending: Result<T, Error>?
	private var resolved = false

	func attach(_ continuation: CheckedContinuation<T, Error>) {
		if resolved { return }
		if let pending {
			self.pending = nil
			resolved = true
			continuation.resume(with: pending)
			return
		}
		self.continuation = continuation
	}

	func resume(_ result: Result<T, Error>) {
		if resolved { return }
		if let continuation {
			self.continuation = nil
			resolved = true
			continuation.resume(with: result)
			return
		}
		if pending == nil {
			pending = result
		}
	}
}

private protocol AnyTask: Sendable {

	/// The task's value; throws `CancellationError` as soon as the caller is cancelled.
	func wait() async throws -> Any

	func outcome() async -> Result<Any, Error>
}

extension Task: AnyTask {

	func wait() async throws -> Any {
		try await awaitRespectingCancellation(self) as Any
	}

	func outcome() async -> Result<Any, Error> {
		await result.map { $0 as Any }.mapError { $0 as Error }
	}
}

private struct UnexpectedSharedTaskTypeError: Error {}

// @unchecked: the closure is called once, by the single task that `Barriers.join` starts with it.
private struct UncheckedSendableBox<Value>: @unchecked Sendable {

	let value: Value

	init(_ value: Value) {
		self.value = value
	}
}

private final actor Barriers {

	static let shared = Barriers()

	// @unchecked: `key` wraps a `Hashable & Sendable` identifier.
	struct Lease: @unchecked Sendable {
		let key: AnyHashable
		let entryID: UInt64
		let task: AnyTask
	}

	private struct Entry {
		let id: UInt64
		let task: AnyTask
		let cancel: @Sendable () -> Void
		var refcount: Int
		var isCancelled: Bool
	}

	/// An entry stays here from its task's start until the task finishes, so a caller arriving later starts anew.
	private var entries: [AnyHashable: Entry] = [:]
	private var lastID: UInt64 = 0

	private init() {}

	/// Joins the running operation for `key`, or starts `operation` if there is none.
	func join<T: Sendable>(_ key: AnyHashable, operation: @escaping @Sendable () async throws -> T) -> Lease {
		if let lease = retain(key) {
			return lease
		}
		// A cancelled operation may still be running; serialize after it.
		let predecessor = entries[key]?.task
		lastID += 1
		let id = lastID
		let task = Task<T, Error> {
			defer { finish(key, id) }
			if let predecessor {
				_ = await predecessor.outcome()
				try Task.checkCancellation()
			}
			return try await operation()
		}
		entries[key] = Entry(id: id, task: task, cancel: { task.cancel() }, refcount: 1, isCancelled: false)
		return Lease(key: key, entryID: id, task: task)
	}

	/// Joins the running operation for `key`; `nil` if there is none.
	func retain(_ key: AnyHashable) -> Lease? {
		guard var entry = entries[key], !entry.isCancelled else { return nil }
		entry.refcount += 1
		entries[key] = entry
		return Lease(key: key, entryID: entry.id, task: entry.task)
	}

	/// Cancels the operation when its last caller leaves before it finishes.
	func release(_ lease: Lease) {
		guard var entry = entries[lease.key], entry.id == lease.entryID else { return }
		entry.refcount -= 1
		if entry.refcount == 0 {
			entry.isCancelled = true
			entry.cancel()
		}
		entries[lease.key] = entry
	}

	private func finish(_ key: AnyHashable, _ id: UInt64) {
		if entries[key]?.id == id {
			entries[key] = nil
		}
	}
}
