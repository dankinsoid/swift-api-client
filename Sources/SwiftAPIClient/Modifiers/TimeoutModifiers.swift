import Foundation

// MARK: - Timeout modifiers

public extension APIClient {

	/// Performs an operation with a timeout and sets the `URLRequest.timeoutInterval` and `APIClient.Configs.timeoutInterval` properties.
	///
	/// - Parameter timeout: The timeout interval to set for the request.
	/// - Returns: An instance of `APIClient` with the specified timeout interval.
	///
	/// If network requests take longer than the specified timeout interval, the request is considered to have timed out.
	/// As a general rule, you should not use short timeout intervals. Instead, you should provide an easy way for the user to cancel a long-running operation.
	///
	/// - Note: This timeout include all operations applied before this modifier.
	/// For example, if you have a `retry` modifier before this one, the timeout will include all the retries.
	/// And opposite, if you have a `retry` modifier after this one, the timeout will apply to the each retry attempt.
	@available(*, deprecated, renamed: "timeout")
	func timeoutInterval(
		_ timeout: TimeInterval,
		fileID: String = #fileID,
		line: UInt = #line
	) -> APIClient {
		self.timeout(timeout, fileID: fileID, line: line)
	}

	/// Performs an operation with a timeout and sets the `URLRequest.timeoutInterval` and `APIClient.Configs.timeoutInterval` properties.
	///
	/// - Parameters:
	///   - timeout: The time to wait for the operation in seconds.
	/// - Returns: An instance of `APIClient` with the specified timeout interval.
	///
	/// If network requests take longer than the specified timeout interval, the request is considered to have timed out.
	/// As a general rule, you should not use short timeout intervals. Instead, you should provide an easy way for the user to cancel a long-running operation.
	///
	/// - Note: This timeout include all operations applied before this modifier.
	/// For example, if you have a `retry` modifier before this one, the timeout will include all the retries.
	/// And opposite, if you have a `retry` modifier after this one, the timeout will apply to the each retry attempt.
	func timeout(
		_ timeout: TimeInterval,
		fileID: String = #fileID,
		line: UInt = #line
	) -> APIClient {
		self.timeout(
			timeout,
			seconds: { $0 },
			sleep: { try await Task.sleep(nanoseconds: UInt64($0 * 1_000_000_000)) },
			fileID: fileID,
			line: line
		)
	}

	/// Performs an operation with a timeout and sets the `URLRequest.timeoutInterval` and `APIClient.Configs.timeoutInterval` properties.
	///
	/// - Parameters:
	///   - timeout: The time to wait for the operation in seconds.
	///   - tolerance: The tolerance for the timeout.
	///   - clock: The clock to use for timing.
	///   - operation: The operation to perform.
	/// - Returns: An instance of `APIClient` with the specified timeout interval.
	///
	/// If network requests take longer than the specified timeout interval, the request is considered to have timed out.
	/// As a general rule, you should not use short timeout intervals. Instead, you should provide an easy way for the user to cancel a long-running operation.
	///
	/// - Note: This timeout include all operations applied before this modifier.
	/// For example, if you have a `retry` modifier before this one, the timeout will include all the retries.
	/// And opposite, if you have a `retry` modifier after this one, the timeout will apply to the each retry attempt.
	@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
	func timeout<C: Clock>(
		_ timeout: C.Instant.Duration,
		tolerance: C.Instant.Duration? = nil,
		clock: C,
		fileID: String = #fileID,
		line: UInt = #line
	) -> APIClient where C.Duration == Duration {
		self.timeout(
			timeout,
            seconds: { Double($0.components.seconds) + Double($0.components.attoseconds) * pow(10.0, -18.0) },
			sleep: { try await clock.sleep(for: $0, tolerance: tolerance) },
			fileID: fileID,
			line: line
		)
	}

	/// Performs an operation with a timeout and sets the `URLRequest.timeoutInterval` and `APIClient.Configs.timeoutInterval` properties.
	///
	/// - Parameters:
	///   - timeout: The time to wait for the operation in seconds.
	///   - tolerance: The tolerance for the timeout.
	/// - Returns: An instance of `APIClient` with the specified timeout interval.
	///
	/// If network requests take longer than the specified timeout interval, the request is considered to have timed out.
	/// As a general rule, you should not use short timeout intervals. Instead, you should provide an easy way for the user to cancel a long-running operation.
	///
	/// - Note: This timeout include all operations applied before this modifier.
	/// For example, if you have a `retry` modifier before this one, the timeout will include all the retries.
	/// And opposite, if you have a `retry` modifier after this one, the timeout will apply to the each retry attempt.
	@available(macOS 13.0, iOS 16.0, watchOS 9.0, tvOS 16.0, *)
	func timeout(
		_ timeout: ContinuousClock.Instant.Duration,
		tolerance: ContinuousClock.Instant.Duration? = nil,
		fileID: String = #fileID,
		line: UInt = #line
	) -> APIClient {
		self.timeout(
			timeout,
			tolerance: tolerance,
			clock: ContinuousClock(),
			fileID: fileID,
			line: line
		)
	}
}

public extension APIClient.Configs {

	/// The timeout interval of the request.
	///
	/// If during a connection attempt the request remains idle for longer than the timeout interval, the request is considered to have timed out.
	/// The default timeout interval is 60 seconds.
	/// As a general rule, you should not use short timeout intervals. Instead, you should provide an easy way for the user to cancel a long-running operation.
	var timeoutInterval: TimeInterval {
		get { self[\.timeoutInterval] ?? 60 }
		set { self[\.timeoutInterval] = newValue }
	}
}

private extension APIClient {

	func timeout<D>(
		_ timeout: D,
		seconds: @escaping @Sendable (D) -> TimeInterval,
		sleep: @escaping @Sendable (D) async throws -> Void,
		fileID: String = #fileID,
		line: UInt = #line
	) -> APIClient {
		let inSeconds = seconds(timeout)
		return configs(\.timeoutInterval, inSeconds)
			.httpClientMiddleware(
				TimeoutMiddleware(
					timeout: timeout,
					seconds: inSeconds,
					sleep: { try await sleep(timeout) },
					fileID: fileID,
					line: line
				)
			)
	}
}

private struct TimeoutMiddleware<D>: HTTPClientMiddleware {

	let timeout: D
	let seconds: TimeInterval
	let sleep: @Sendable () async throws -> Void
	let fileID: String
	let line: UInt

	func execute<T>(
		request: HTTPRequest,
		body: RequestBody?,
		configs: APIClient.Configs,
		next: @escaping @Sendable (HTTPRequest, RequestBody?, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		try await withTimeout(
			timeout,
			seconds: { _ in seconds },
			sleep: { _ in try await sleep() },
			fileID: fileID,
			line: line
		) {
			try await next(request, body, configs)
		}
	}
}
