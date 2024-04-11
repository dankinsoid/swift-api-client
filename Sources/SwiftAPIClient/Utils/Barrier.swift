import Foundation

/// Executes a given task with synchronization on a shared resource identified by `taskIdentifier`.
/// This function ensures that tasks associated with the same identifier are executed in a way that respects
/// the shared nature of the resource, possibly blocking or queuing tasks as necessary.
/// - Parameters:
///   - id: A unique identifier for the task, correlating to the shared resource that might require blocking or synchronization.
///   - task: The async task to be executed, which may read from or write to the shared resource.
/// - Returns: The result of the task if it is successfully completed.
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
            runtimeWarn("Unexpected task type found in the barrier.")
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

/// Executes a given task with synchronization on a shared resource identified by `taskIdentifier`.
/// This function ensures that tasks associated with the same identifier are executed in a way that respects
/// the shared nature of the resource, possibly blocking or queuing tasks as necessary.
/// - Parameters:
///   - id: A unique identifier for the task, correlating to the shared resource that might require blocking or synchronization.
///   - task: The async task to be executed, which may read from or write to the shared resource.
/// - Returns: The result of the task if it is successfully completed.
public func withSynchronizedAccess<T, ID: Hashable>(
    id taskIdentifier: ID,
    task: @escaping @Sendable () async -> T
) async -> T {
    if let cached = await Barriers.shared.tasks[taskIdentifier] {
        if let task = cached as? Task<T, Error> {
            runtimeWarn("Attempted to access a throwing synchronized task from a non-throwing context.")
            if let result = try? await task.value {
                return result
            }
        } else if let task = cached as? Task<T, Never> {
            return await task.value
        } else {
            runtimeWarn("Unexpected task type found in the barrier.")
        }
    }
    let task = Task(operation: task)
    await Barriers.shared.setTask(for: taskIdentifier, task: task)
    let result = await task.value
    await Barriers.shared.removeTask(for: taskIdentifier)
    return result
}

private final actor Barriers {
    
    static let shared = Barriers()
    
    var tasks: [AnyHashable: Any] = [:]
    
    private init() {}
    
    func removeTask(for key: AnyHashable) {
        tasks[key] = nil
    }
    
    func setTask<T, E: Error>(for key: AnyHashable, task: Task<T, E>) {
        tasks[key] = task
    }
}
