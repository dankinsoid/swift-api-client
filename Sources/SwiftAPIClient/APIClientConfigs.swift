import Foundation
import Logging
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient {

	/// A struct representing the configuration settings for a `APIClient`.
	struct Configs {

		private var values: [PartialKeyPath<APIClient.Configs>: Any] = [:]

		/// Initializes a new configuration set for `APIClient`.
		public init() {
		}

		/// Provides subscript access to configuration values based on their key paths.
		/// - Parameter keyPath: A `WritableKeyPath` to the configuration property.
		/// - Returns: The value of the configuration property if it exists, or `nil` otherwise.
		public subscript<T>(_ keyPath: WritableKeyPath<APIClient.Configs, T>) -> T? {
			get { values[keyPath] as? T }
			set { values[keyPath] = newValue }
		}

		/// Provides subscript access to configuration values based on their key paths.
		/// - Parameter keyPath: A `WritableKeyPath` to the configuration property.
		/// - Returns: The value of the configuration property if it exists, or `nil` otherwise.
		public subscript<T>(_ keyPath: WritableKeyPath<APIClient.Configs, T?>) -> T? {
			get { values[keyPath] as? T }
			set { values[keyPath] = newValue }
		}

		/// Returns a new `Configs` instance with a modified configuration value.
		/// - Parameters:
		///   - keyPath: A `WritableKeyPath` to the configuration property to be modified.
		///   - value: The new value to set for the specified configuration property.
		/// - Returns: A new `Configs` instance with the updated configuration setting.
		public func with<T>(_ keyPath: WritableKeyPath<APIClient.Configs, T>, _ value: T) -> APIClient.Configs {
			var result = self
			result[keyPath: keyPath] = value
			return result
		}
	}
}

/// Provides a default value for a given configuration, which can differ between live, test, and preview environments.
/// - Parameters:
///   - live: An autoclosure returning the value for the live environment.
///   - test: An optional autoclosure returning the value for the test environment.
///   - preview: An optional autoclosure returning the value for the preview environment.
/// - Returns: The appropriate value depending on the current environment.
public func valueFor<Value>(
	live: @autoclosure () -> Value,
	test: @autoclosure () -> Value? = nil,
	preview: @autoclosure () -> Value? = nil
) -> Value {
	#if DEBUG
	if _isPreview {
		return preview() ?? test() ?? live()
	} else if _XCTIsTesting {
		return test() ?? preview() ?? live()
	} else {
		return live()
	}
	#else
	return live()
	#endif
}

private let _XCTIsTesting: Bool = ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath")
private let _isPreview: Bool = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
