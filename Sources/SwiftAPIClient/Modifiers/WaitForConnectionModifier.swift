#if canImport(SystemConfiguration)
import Foundation

public extension APIClient {

	/// Wait for a connection to be equal to the given connection or available if not specified.
	/// - Parameters:
	///   - connection: The connection to wait for. If `nil` it will wait for any connection.
	///   - timeout: The time to wait for the connection. If `nil` it will wait indefinitely.
	///   - hostname: The hostname to monitor. If `nil` it will monitor the default route.
	func waitForConnection(
		_ connection: Reachability.Connection? = nil,
		hostname: String? = nil,
		fileID: String = #file,
		line: UInt = #line
	) -> APIClient {
		httpClientMiddleware(
			WaitForConnectionMiddleware(
				connection: connection,
				fileID: fileID,
				line: line
			) {
				if let cached = await Reachabilities.shared.reachabilities[hostname] {
					return cached
				} else if let hostname {
					let reachability = try Reachability(hostname: hostname)
					await Reachabilities.shared.set(reachability, for: hostname)
					return reachability
				} else {
					let reachability = try Reachability()
					await Reachabilities.shared.set(reachability, for: nil)
					return reachability
				}
			}
		)
	}

	/// Wait for a connection to be equal to the given connection or available if not specified.
	/// - Parameters:
	///   - connection: The connection to wait for. If `nil` it will wait for any connection.
	///   - timeout: The time to wait for the connection. If `nil` it will wait indefinitely.
	///   - reachability: The reachability instance to monitor.
	func waitForConnection(
		_ connection: Reachability.Connection? = nil,
		reachability: Reachability,
		fileID: String = #file,
		line: UInt = #line
	) -> APIClient {
		httpClientMiddleware(
			WaitForConnectionMiddleware(
				connection: connection,
				fileID: fileID,
				line: line
			) {
				reachability
			}
		)
	}
}

private struct WaitForConnectionMiddleware: HTTPClientMiddleware {

	let connection: Reachability.Connection?
	let fileID: String
	let line: UInt
	let createReachibility: () async throws -> Reachability

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		let reachability = try await createReachibility()

		func execute() async throws -> (T, HTTPResponse) {
			try await wait(reachability: reachability)
			do {
				return try await next(request, configs)
			} catch {
				try Task.checkCancellation()
				if (error as? URLError)?.networkUnavailableReason != nil || reachability.connection == .unavailable && connection == nil {
					return try await execute()
				}
				throw error
			}
		}

		return try await execute()
	}

	private func wait(reachability: Reachability) async throws {
		try await reachability.wait(
			for: { $0 == connection || connection == nil && $0 != .unavailable },
			timeout: nil,
			fileID: fileID,
			line: line
		)
	}
}

private final actor Reachabilities {

	static let shared = Reachabilities()

	var reachabilities: [String?: Reachability] = [:]

	func set(_ reachability: Reachability, for hostname: String?) {
		reachabilities[hostname] = reachability
	}
}
#endif
