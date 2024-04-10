#if canImport(SystemConfiguration)
import Foundation
import SystemConfiguration

/// `Reachability` can be used to monitor the network status of a device.
public final class Reachability {

	public enum Connection: CustomStringConvertible {

		case unavailable, wifi, cellular

		public var description: String {
			switch self {
			case .cellular: return "Cellular"
			case .wifi: return "WiFi"
			case .unavailable: return "No Connection"
			}
		}
	}

	/// Set to `false` to force Reachability.connection to .none when on cellular connection (default value `true`)
	public var allowsCellularConnection: Bool {
		get {
			lock.lock()
			defer { lock.unlock() }
			return _allowsCellularConnection
		}
		set {
			lock.lock()
			defer { lock.unlock() }
			_allowsCellularConnection = newValue
		}
	}

	private var _allowsCellularConnection = true

	/// The notification center on which "reachability changed" events are being posted
	public var notificationCenter: NotificationCenter {
		get {
			lock.lock()
			defer { lock.unlock() }
			return _notificationCenter
		}
		set {
			lock.lock()
			defer { lock.unlock() }
			_notificationCenter = newValue
		}
	}

	private var _notificationCenter: NotificationCenter = .default

	/// Current connection status
	public var connection: Connection {
		let flags = flags
		if flags == nil {
			try? setReachabilityFlags()
		}

		switch flags?.connection {
		case .unavailable?, nil: return .unavailable
		case .cellular?: return allowsCellularConnection ? .cellular : .unavailable
		case .wifi?: return .wifi
		}
	}

	private var subscriptions: [UUID: (Connection) -> Void] = [:]
	private var notifierRunning = false
	private let reachabilityRef: SCNetworkReachability
	private let reachabilitySerialQueue: DispatchQueue
	private let notificationQueue: DispatchQueue?
	private let lock = NSRecursiveLock()
	private var flags: SCNetworkReachabilityFlags? {
		get {
			lock.lock()
			defer { lock.unlock() }
			return _flags
		}
		set {
			lock.lock()
			let needNotify = _flags != newValue
			_flags = newValue
			lock.unlock()
			if needNotify {
				notifyReachabilityChanged()
			}
		}
	}

	private var _flags: SCNetworkReachabilityFlags?

	/// Initializes a new `Reachability` instance.
	/// - Parameters:
	///  - reachabilityRef: The `SCNetworkReachability` instance to use.
	///  - queueQoS: The quality of service for the dispatch queue to use.
	///  - targetQueue: The target dispatch queue for the reachability instance.
	///  - notificationQueue: The dispatch queue on which to post notifications.
	public required init(
		reachabilityRef: SCNetworkReachability,
		queueQoS: DispatchQoS = .default,
		targetQueue: DispatchQueue? = nil,
		notificationQueue: DispatchQueue? = .main
	) {
		self.reachabilityRef = reachabilityRef
		reachabilitySerialQueue = DispatchQueue(label: "swift.api.client.reachability", qos: queueQoS, target: targetQueue)
		self.notificationQueue = notificationQueue
	}

	/// Initializes a new `Reachability` instance.
	/// - Parameters:
	///  - hostname: The hostname to monitor.
	///  - queueQoS: The quality of service for the dispatch queue to use.
	///  - targetQueue: The target dispatch queue for the reachability instance.
	///  - notificationQueue: The dispatch queue on which to post notifications.
	public convenience init(
		hostname: String,
		queueQoS: DispatchQoS = .default,
		targetQueue: DispatchQueue? = nil,
		notificationQueue: DispatchQueue? = .main
	) throws {
		guard let ref = SCNetworkReachabilityCreateWithName(nil, hostname) else {
			throw ReachabilityError.failedToCreateWithHostname(hostname, SCError())
		}
		self.init(reachabilityRef: ref, queueQoS: queueQoS, targetQueue: targetQueue, notificationQueue: notificationQueue)
	}

	/// Initializes a new `Reachability` instance.
	/// - Parameters:
	/// - queueQoS: The quality of service for the dispatch queue to use.
	/// - targetQueue: The target dispatch queue for the reachability instance.
	/// - notificationQueue: The dispatch queue on which to post notifications.
	public convenience init(
		queueQoS: DispatchQoS = .default,
		targetQueue: DispatchQueue? = nil,
		notificationQueue: DispatchQueue? = .main
	) throws {
		var zeroAddress = sockaddr()
		zeroAddress.sa_len = UInt8(MemoryLayout<sockaddr>.size)
		zeroAddress.sa_family = sa_family_t(AF_INET)

		guard let ref = SCNetworkReachabilityCreateWithAddress(nil, &zeroAddress) else {
			throw ReachabilityError.failedToCreateWithAddress(zeroAddress, SCError())
		}

		self.init(reachabilityRef: ref, queueQoS: queueQoS, targetQueue: targetQueue, notificationQueue: notificationQueue)
	}

	deinit {
		stopNotifier()
	}
}

public extension Reachability {

	// MARK: - *** Notifier methods ***

	func startNotifier() throws {
		guard !notifierRunning else { return }

		let callback: SCNetworkReachabilityCallBack = { reachability, flags, info in
			guard let info else { return }

			// `weakifiedReachability` is guaranteed to exist by virtue of our
			// retain/release callbacks which we provided to the `SCNetworkReachabilityContext`.
			let weakifiedReachability = Unmanaged<ReachabilityWeakifier>.fromOpaque(info).takeUnretainedValue()

			// The weak `reachability` _may_ no longer exist if the `Reachability`
			// object has since been deallocated but a callback was already in flight.
			weakifiedReachability.reachability?.flags = flags
		}

		let weakifiedReachability = ReachabilityWeakifier(self)
		let opaqueWeakifiedReachability = Unmanaged<ReachabilityWeakifier>.passUnretained(weakifiedReachability).toOpaque()

		var context = SCNetworkReachabilityContext(
			version: 0,
			info: UnsafeMutableRawPointer(opaqueWeakifiedReachability),
			retain: { (info: UnsafeRawPointer) -> UnsafeRawPointer in
				let unmanagedWeakifiedReachability = Unmanaged<ReachabilityWeakifier>.fromOpaque(info)
				_ = unmanagedWeakifiedReachability.retain()
				return UnsafeRawPointer(unmanagedWeakifiedReachability.toOpaque())
			},
			release: { (info: UnsafeRawPointer) in
				let unmanagedWeakifiedReachability = Unmanaged<ReachabilityWeakifier>.fromOpaque(info)
				unmanagedWeakifiedReachability.release()
			},
			copyDescription: { (info: UnsafeRawPointer) -> Unmanaged<CFString> in
				let unmanagedWeakifiedReachability = Unmanaged<ReachabilityWeakifier>.fromOpaque(info)
				let weakifiedReachability = unmanagedWeakifiedReachability.takeUnretainedValue()
				let description = weakifiedReachability.reachability?.description ?? "nil"
				return Unmanaged.passRetained(description as CFString)
			}
		)

		if !SCNetworkReachabilitySetCallback(reachabilityRef, callback, &context) {
			stopNotifier()
			throw ReachabilityError.unableToSetCallback(SCError())
		}

		if !SCNetworkReachabilitySetDispatchQueue(reachabilityRef, reachabilitySerialQueue) {
			stopNotifier()
			throw ReachabilityError.unableToSetDispatchQueue(SCError())
		}

		// Perform an initial check
		try setReachabilityFlags()

		lock.lock()
		notifierRunning = true
		lock.unlock()
	}

	func stopNotifier() {
		defer {
			lock.lock()
			notifierRunning = false
			lock.unlock()
		}

		SCNetworkReachabilitySetCallback(reachabilityRef, nil, nil)
		SCNetworkReachabilitySetDispatchQueue(reachabilityRef, nil)
	}

	/// A closure to be called (on notificationQueue) when the network reachability status changes.
	/// - Parameter observer: The closure to be called.
	/// - Returns: A closure that can be called to cancel the observation.
	/// - Throws: `ReachabilityError` if the notifier cannot be started.
	@discardableResult
	func subscribe(_ observer: @escaping (Connection) -> Void) throws -> () -> Void {
		let id = UUID()
		lock.lock()
		subscriptions[id] = observer
		let isNotifying = notifierRunning
		lock.unlock()

		if isNotifying {
			let notify = { [connection] in observer(connection) }
			notificationQueue?.async(execute: notify) ?? notify()
		} else {
			try startNotifier()
		}

		return { [weak self] in
			self?.unsubscribe(id: id)
		}
	}

	/// Waits until the connection satisfies the condition.
	/// - Parameters:
	///   - condition: The condition to wait for.
	///   - timeout: The maximum time to wait for the condition to be satisfied.
	/// - Throws: `CancellationError` if the task is cancelled ,`ReachabilityError` if the notifier cannot be started, or `TimeoutError` if the timeout is reached.
	func wait(
		for condition: @escaping (Connection) -> Bool,
		timeout: TimeInterval? = nil,
		fileID: String = #fileID,
		line: UInt = #line
	) async throws {
		guard !condition(connection) else { return }
		return try await withTimeout(timeout, fileID: fileID, line: line) {
			try await self.waitWithoutTimeLimit(for: condition)
		}
	}

	/// Waits until the connection is equal to the given connection.
	/// - Parameters:
	///   - connection: The connection to wait for.
	///   - timeout: The maximum time to wait for the connection to be equal to the given connection.
	/// - Throws: `CancellationError` if the task is cancelled ,`ReachabilityError` if the notifier cannot be started, or `TimeoutError` if the timeout is reached.
	func wait(
		for connection: Connection,
		timeout: TimeInterval? = nil,
		fileID: String = #fileID,
		line: UInt = #line
	) async throws {
		try await wait(
			for: { $0 == connection },
			timeout: timeout,
			fileID: fileID,
			line: line
		)
	}

	/// Waits until the connection is available.
	/// - Parameters:
	///   - timeout: The maximum time to wait for the connection to be equal to the given connection.
	/// - Throws: `CancellationError` if the task is cancelled ,`ReachabilityError` if the notifier cannot be started, or `TimeoutError` if the timeout is reached.
	func waitForAvailable(
		timeout: TimeInterval? = nil,
		fileID: String = #fileID,
		line: UInt = #line
	) async throws {
		try await wait(
			for: { $0 != .unavailable },
			timeout: timeout,
			fileID: fileID,
			line: line
		)
	}
}

#if canImport(Combine)
import Combine

public extension Reachability {

	/// A publisher that emits the connection status when the connection changes.
	var connectionPublisher: AnyPublisher<Connection, Error> {
		Publishers.Create { [self] send, complete, handler in
			let subscription = try subscribe(send)
			handler {
				subscription()
			}
		}
		.eraseToAnyPublisher()
	}
}
#endif

extension Reachability: CustomStringConvertible {

	public var description: String {
		flags?.description ?? "unavailable flags"
	}
}

public enum ReachabilityError: Error {

	case failedToCreateWithAddress(sockaddr, Int32)
	case failedToCreateWithHostname(String, Int32)
	case unableToSetCallback(Int32)
	case unableToSetDispatchQueue(Int32)
	case unableToGetFlags(Int32)
}

public extension Notification.Name {

	/// The notification is posted when the network reachability of the app changes.
	///
	/// The notification object is the `Reachability` instance.
	///
	/// The `userInfo` dictionary contains the connection status in "connection" field and availability status in "isAvailable" field.
	static let reachabilityChanged = Notification.Name("reachabilityChanged")
}

private extension Reachability {

	func setReachabilityFlags() throws {
		var flags = SCNetworkReachabilityFlags()
		if !SCNetworkReachabilityGetFlags(reachabilityRef, &flags) {
			stopNotifier()
			throw ReachabilityError.unableToGetFlags(SCError())
		}
		self.flags = flags
	}

	func notifyReachabilityChanged() {
		let notify = { [weak self] in
			guard let self else { return }
			let connection = self.connection
			self.lock.lock()
			let subscriptions = self.subscriptions
			self.lock.unlock()
			for subscription in subscriptions {
				subscription.value(connection)
			}
			self.notificationCenter.post(
				name: .reachabilityChanged,
				object: self,
				userInfo: [
					"connection": connection,
					"isAvailable": connection != .unavailable,
				]
			)
		}

		// notify on the configured `notificationQueue`, or the caller's (i.e. `reachabilitySerialQueue`)
		notificationQueue?.async(execute: notify) ?? notify()
	}

	func unsubscribe(id: UUID) {
		lock.lock()
		subscriptions[id] = nil
		lock.unlock()
	}

	func waitWithoutTimeLimit(
		for condition: @escaping (Connection) -> Bool
	) async throws {
		guard !condition(connection) else { return }
		let wrapper = WaitingWrapper()
		let subscription = try subscribe { connection in
			if condition(connection) {
				Task {
					await wrapper.setFulfilled(nil)
				}
			}
		}
		try await withTaskCancellationHandler {
			let _: Void = try await withCheckedThrowingContinuation { continuation in
				Task {
					await wrapper.setOnFulfilled {
						if let error = $0 {
							continuation.resume(throwing: error)
						} else {
							continuation.resume()
						}
						subscription()
					}
				}
			}
		} onCancel: {
			Task {
				await wrapper.setFulfilled(CancellationError())
			}
		}
	}
}

private extension SCNetworkReachabilityFlags {

	typealias Connection = Reachability.Connection

	var connection: Connection {
		guard isReachableFlagSet else { return .unavailable }

		// If we're reachable, but not on an iOS device (i.e. simulator), we must be on WiFi
		#if targetEnvironment(simulator)
		return .wifi
		#else
		var connection = Connection.unavailable

		if !isConnectionRequiredFlagSet {
			connection = .wifi
		}

		if isConnectionOnTrafficOrDemandFlagSet {
			if !isInterventionRequiredFlagSet {
				connection = .wifi
			}
		}

		if isOnWWANFlagSet {
			connection = .cellular
		}

		return connection
		#endif
	}

	var isOnWWANFlagSet: Bool {
		#if os(iOS)
		return contains(.isWWAN)
		#else
		return false
		#endif
	}

	var isReachableFlagSet: Bool {
		contains(.reachable)
	}

	var isConnectionRequiredFlagSet: Bool {
		contains(.connectionRequired)
	}

	var isInterventionRequiredFlagSet: Bool {
		contains(.interventionRequired)
	}

	var isConnectionOnTrafficFlagSet: Bool {
		contains(.connectionOnTraffic)
	}

	var isConnectionOnDemandFlagSet: Bool {
		contains(.connectionOnDemand)
	}

	var isConnectionOnTrafficOrDemandFlagSet: Bool {
		!intersection([.connectionOnTraffic, .connectionOnDemand]).isEmpty
	}

	var isTransientConnectionFlagSet: Bool {
		contains(.transientConnection)
	}

	var isLocalAddressFlagSet: Bool {
		contains(.isLocalAddress)
	}

	var isDirectFlagSet: Bool {
		contains(.isDirect)
	}

	var description: String {
		let W = isOnWWANFlagSet ? "W" : "-"
		let R = isReachableFlagSet ? "R" : "-"
		let c = isConnectionRequiredFlagSet ? "c" : "-"
		let t = isTransientConnectionFlagSet ? "t" : "-"
		let i = isInterventionRequiredFlagSet ? "i" : "-"
		let C = isConnectionOnTrafficFlagSet ? "C" : "-"
		let D = isConnectionOnDemandFlagSet ? "D" : "-"
		let l = isLocalAddressFlagSet ? "l" : "-"
		let d = isDirectFlagSet ? "d" : "-"

		return "\(W)\(R) \(c)\(t)\(i)\(C)\(D)\(l)\(d)"
	}
}

/**
 `ReachabilityWeakifier` weakly wraps the `Reachability` class
 in order to break retain cycles when interacting with CoreFoundation.

 CoreFoundation callbacks expect a pair of retain/release whenever an
 opaque `info` parameter is provided. These callbacks exist to guard
 against memory management race conditions when invoking the callbacks.

 #### Race Condition

 If we passed `SCNetworkReachabilitySetCallback` a direct reference to our
 `Reachability` class without also providing corresponding retain/release
 callbacks, then a race condition can lead to crashes when:
 - `Reachability` is deallocated on thread X
 - A `SCNetworkReachability` callback(s) is already in flight on thread Y

 #### Retain Cycle

 If we pass `Reachability` to CoreFoundtion while also providing retain/
 release callbacks, we would create a retain cycle once CoreFoundation
 retains our `Reachability` class. This fixes the crashes and his how
 CoreFoundation expects the API to be used, but doesn't play nicely with
 Swift/ARC. This cycle would only be broken after manually calling
 `stopNotifier()` — `deinit` would never be called.

 #### ReachabilityWeakifier

 By providing both retain/release callbacks and wrapping `Reachability` in
 a weak wrapper, we:
 - interact correctly with CoreFoundation, thereby avoiding a crash.
 See "Memory Management Programming Guide for Core Foundation".
 - don't alter the public API of `Reachability.swift` in any way
 - still allow for automatic stopping of the notifier on `deinit`.
 */
private final class ReachabilityWeakifier {

	weak var reachability: Reachability?

	init(_ reachability: Reachability) {
		self.reachability = reachability
	}
}

private final actor WaitingWrapper {

	private var isFulfilled = false
	private var error: Error?
	private var onFulfilled: (Error?) -> Void = { _ in }

	func setOnFulfilled(_ onFulfilled: @escaping (Error?) -> Void) {
		if isFulfilled {
			onFulfilled(error)
		} else {
			self.onFulfilled = onFulfilled
		}
	}

	func setFulfilled(_ error: Error?) {
		guard !isFulfilled else { return }
		isFulfilled = true
		self.error = error
		onFulfilled(error)
	}
}
#endif
