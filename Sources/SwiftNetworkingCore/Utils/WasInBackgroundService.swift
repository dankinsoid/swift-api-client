#if canImport(UIKit)
import Foundation
import UIKit

/// A protocol for tracking whether an app has been in the background.
public protocol WasInBackgroundService {

	/// Indicates whether the app was in the background.
	var wasInBackground: Bool { get }
	/// Starts monitoring for the app entering the background.
	func start()
	/// Resets the background status.
	func reset()
}

/// A mock implementation of `WasInBackgroundService` for testing purposes.
public struct MockWasInBackgroundService: WasInBackgroundService {

	public var wasInBackground: Bool

	/// Initializes the service with a mock background status.
	public init(wasInBackground: Bool = false) {
		self.wasInBackground = wasInBackground
	}

	public func start() {}

	public func reset() {}
}

/// The default implementation of `WasInBackgroundService` using system notifications.
public final class DefaultWasInBackgroundService: WasInBackgroundService {

	public private(set) var wasInBackground = false
	private var observer: NSObjectProtocol?

	public init() {
		start()
	}

	public func start() {
		guard observer == nil else { return }
		observer = NotificationCenter.default.addObserver(
			forName: UIApplication.didEnterBackgroundNotification,
			object: nil,
			queue: .main
		) { [weak self] _ in
			self?.wasInBackground = true
		}
	}

	public func reset() {
		wasInBackground = false
	}
}

public extension WasInBackgroundService where Self == DefaultWasInBackgroundService {

	/// Default implementation of `WasInBackgroundService`.
	static var `default`: Self { DefaultWasInBackgroundService() }
}
#endif
