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
public func withThrowingSynchronizedAccess<T, ID: Hashable>(
	id taskIdentifier: ID,
	task: @escaping @Sendable () async throws -> T
) async throws -> T {
	if let cached = await Barriers.shared.tasks[taskIdentifier] {
		if let task = cached as? Task<T, Error> {
			return try await task.value
		} else if let task = cached as? Task<T, Never> {
			return await task.value
		} else {
			//            runtimeWarn("Unexpected task type found in the barrier.")
		}
	}
	let task = Task(operation: task)
	await Barriers.shared.setTask(for: taskIdentifier, task: task)
	do {
		let result = try await task.value
		await Barriers.shared.removeTask(for: taskIdentifier)
		return result
	} catch {
		await Barriers.shared.removeTask(for: taskIdentifier)
		throw error
	}
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
public func withSynchronizedAccess<T, ID: Hashable>(
	id taskIdentifier: ID,
	task: @escaping @Sendable () async -> T
) async -> T {
	if let cached = await Barriers.shared.tasks[taskIdentifier] {
		if let task = cached as? Task<T, Error> {
			//            logger("Attempted to access a throwing synchronized task from a non-throwing context.")
			if let result = try? await task.value {
				return result
			}
		} else if let task = cached as? Task<T, Never> {
			return await task.value
		} else {
			//            runtimeWarn("Unexpected task type found in the barrier.")
		}
	}
	let task = Task(operation: task)
	await Barriers.shared.setTask(for: taskIdentifier, task: task)
	let result = await task.value
	await Barriers.shared.removeTask(for: taskIdentifier)
	return result
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
public func waitForThrowingSynchronizedAccess<ID: Hashable, T>(id taskIdentifier: ID, of type: T.Type = T.self) async throws -> T? {
	guard let cached = await Barriers.shared.tasks[taskIdentifier] else {
		return nil
	}
	return try await cached.wait() as? T
	//    if result == nil, !(type is Void.Type) {
	//        runtimeWarn("Unexpected task type found in the waitForThrowingSynchronizedAccess.")
	//    }
	//    return result
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
public func waitForSynchronizedAccess<ID: Hashable, T>(id taskIdentifier: ID, of type: T.Type = T.self) async -> T? {
	guard let cached = await Barriers.shared.tasks[taskIdentifier] else {
		return nil
	}
	do {
		return try await cached.wait() as? T
		//        if result == nil, !(type is Void.Type) {
		//            runtimeWarn("Unexpected task type found in the waitForThrowingSynchronizedAccess.")
		//        }
		//        return result
	} catch {
		return nil
	}
}

private protocol AnyTask {

	func wait() async throws -> Any
}

extension Task: AnyTask {

	func wait() async throws -> Any {
		try await value
	}
}

private final actor Barriers {

	static let shared = Barriers()

	var tasks: [AnyHashable: AnyTask] = [:]

	private init() {}

	func removeTask(for key: AnyHashable) {
		tasks[key] = nil
	}

	func setTask<T, E: Error>(for key: AnyHashable, task: Task<T, E>) {
		tasks[key] = task
	}
}
