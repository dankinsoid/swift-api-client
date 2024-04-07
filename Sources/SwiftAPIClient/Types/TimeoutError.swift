import Foundation

/// Performs an operation with a timeout.
///
/// - Parameters:
///   - timeout: The time to wait for the operation in seconds. If `nil` it will wait indefinitely.
///   - operation: The operation to perform.
/// - Returns: The result of the operation.
/// - Throws: An `TimeoutError` if the operation fails or times out or any error thrown by the operation.
public func withTimeout<T>(
	_ timeout: TimeInterval?,
	fileID: String = #fileID,
	line: UInt = #line,
	operation: @escaping @Sendable () async throws -> T
) async throws -> T {
	try await withTimeout(
		timeout,
		seconds: { $0 },
		sleep: { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) },
		fileID: fileID,
		line: line,
		operation: operation
	)
}

/// Performs an operation with a timeout.
///
/// - Parameters:
///   - timeout: The time to wait for the operation. If `nil` it will wait indefinitely.
///   - tolerance: The tolerance for the timeout.
///   - clock: The clock to use for timing.
///   - operation: The operation to perform.
/// - Returns: The result of the operation.
/// - Throws: An `TimeoutError` if the operation fails or times out or any error thrown by the operation.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func withTimeout<T, C: Clock>(
	_ timeout: C.Instant.Duration?,
	tolerance: C.Instant.Duration? = nil,
	clock: C,
	fileID: String = #fileID,
	line: UInt = #line,
	operation: @escaping @Sendable () async throws -> T
) async throws -> T where C.Duration == Duration {
	try await withTimeout(
		timeout,
		seconds: { Double($0.components.seconds) + Double($0.components.attoseconds) * pow(10, -18) },
		sleep: { try await clock.sleep(for: $0, tolerance: tolerance) },
		fileID: fileID,
		line: line,
		operation: operation
	)
}

/// Performs an operation with a timeout using a continuous clock.
///
/// - Parameters:
///   - timeout: The time to wait for the operation. If `nil` it will wait indefinitely.
///   - tolerance: The tolerance for the timeout.
///   - operation: The operation to perform.
/// - Returns: The result of the operation.
/// - Throws: An `TimeoutError` if the operation fails or times out or any error thrown by the operation.
@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
public func withTimeout<T>(
	_ timeout: ContinuousClock.Instant.Duration?,
	tolerance: ContinuousClock.Instant.Duration? = nil,
	fileID: String = #fileID,
	line: UInt = #line,
	operation: @escaping @Sendable () async throws -> T
) async throws -> T {
	try await withTimeout(
		timeout,
		tolerance: tolerance,
		clock: ContinuousClock(),
		fileID: fileID,
		line: line,
		operation: operation
	)
}

func withTimeout<T, D>(
	_ timeout: D?,
	seconds: @escaping @Sendable (D) -> TimeInterval,
	sleep: @escaping @Sendable (D) async throws -> Void,
	fileID: String = #fileID,
	line: UInt = #line,
	operation: @escaping @Sendable () async throws -> T
) async throws -> T {
	guard let timeout else {
		return try await operation()
	}
	let inSeconds = seconds(timeout)
	guard inSeconds > 0 else {
		throw TimeoutError(timeout: 0, fileID: fileID, line: line)
	}
	return try await withThrowingTaskGroup(of: T.self, returning: T.self) { group in
		group.addTask(operation: operation)
		group.addTask {
			try await sleep(timeout)
			throw TimeoutError(timeout: inSeconds, fileID: fileID, line: line)
		}
		defer {
			group.cancelAll()
		}
		guard let result = try await group.next() else {
			throw ImpossibleError()
		}
		return result
	}
}

/// An error that is thrown when a timeout occurs.
public struct TimeoutError: LocalizedError {

	public var timeout: TimeInterval?
	private let fileID: String
	private let line: UInt

	public init(timeout: TimeInterval? = nil, fileID: String = #fileID, line: UInt = #line) {
		self.timeout = timeout
		self.fileID = fileID
		self.line = line
	}

	public var errorDescription: String? {
		description
	}
}

extension TimeoutError: CustomStringConvertible {

	public var description: String {
		if let timeout {
			return "The action timed out after \(timeout) seconds. (fileID: \(fileID), line: \(line))"
		} else {
			return "The action timed out. (fileID: \(fileID), line: \(line))"
		}
	}
}

private struct ImpossibleError: Error {}
