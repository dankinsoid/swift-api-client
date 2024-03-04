#if canImport(Reachability)
import Foundation
import Reachability

/// A protocol for monitoring and waiting for network reachability changes.
public protocol ReachabilityService {

	/// The current network connection status.
	var connection: Reachability.Connection { get }

	/// Waits asynchronously for a network connection that satisfies the given condition.
	/// - Parameter connection: A closure that evaluates whether a given `Reachability.Connection` meets the desired criteria.
	func wait(for connection: @escaping (Reachability.Connection) -> Bool) async
}

public extension ReachabilityService {

	/// Indicates whether there is an available network connection.
	var isReachable: Bool {
		connection != .unavailable
	}

	/// Waits asynchronously until the specified network connection status is met.
	func wait(for connection: Reachability.Connection) async {
		await wait {
			$0 == connection
		}
	}

	/// Waits asynchronously until a network connection becomes available.
	func waitReachable() async {
		await wait {
			$0 != .unavailable
		}
	}
}

/// A mock implementation of `ReachabilityService`, primarily for testing purposes.
public struct MockReachabilityService: ReachabilityService {

	public var connection: Reachability.Connection

	/// Initializes the service with a mock connection status.
	public init(connection: Reachability.Connection = .wifi) {
		self.connection = connection
	}

	public func wait(for connection: @escaping (Reachability.Connection) -> Bool) async {}
}

/// A default implementation of `ReachabilityService` using the `Reachability` framework.
public final actor DefaultReachabilityService: ReachabilityService {

	/// Shared instance of `DefaultReachabilityService`.
	public static let shared = DefaultReachabilityService()

	/// The current network connection status, nonisolated to the actor context.
	public nonisolated var connection: Reachability.Connection {
		reachability?.connection ?? .unavailable
	}

	public init(reachability: Reachability?) {
		self.reachability = reachability
	}

	private let reachability: Reachability?
	private var didStart = false
	private var subscribers: [(Reachability.Connection) -> Bool] = []

	public init() {
		self.init(reachability: try? Reachability())
	}

	/// Waits asynchronously for a network connection that satisfies the given condition.
	///
	/// - Parameters:
	///		- connection: A closure that evaluates whether a given `Reachability.Connection` meets the desired criteria.
	public func wait(for connection: @escaping (Reachability.Connection) -> Bool) async {
		guard !connection(self.connection) else { return }
		startIfNeeded()
		await withCheckedContinuation {
			subscribe(condition: connection, continuation: $0)
		}
	}

	private func startIfNeeded() {
		try? reachability?.startNotifier()
		guard let reachability, !didStart else { return }
		didStart = true
		let currentWhenReachable = reachability.whenReachable
		reachability.whenReachable = { [weak self] reachability in
			currentWhenReachable?(reachability)
			Task { [weak self] in
				await self?.update(with: reachability)
			}
		}
		let currentWhenUnreachable = reachability.whenUnreachable
		reachability.whenUnreachable = { [weak self] reachability in
			currentWhenUnreachable?(reachability)
			Task { [weak self] in
				await self?.update(with: reachability)
			}
		}
	}

	private func update(with reachability: Reachability) {
		subscribers = subscribers.filter {
			!$0(reachability.connection)
		}
	}

	private func subscribe(condition: @escaping (Reachability.Connection) -> Bool, continuation: CheckedContinuation<Void, Never>) {
		subscribers.append {
			if condition($0) {
				continuation.resume()
				return true
			}
			return false
		}
	}
}

public extension ReachabilityService where Self == DefaultReachabilityService {

	/// A convenient static property to access the shared default reachability service.
	static var `default`: DefaultReachabilityService {
		.shared
	}
}
#endif
