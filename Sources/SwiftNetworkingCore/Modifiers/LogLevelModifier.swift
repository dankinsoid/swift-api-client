import Foundation
import Logging

public extension NetworkClient {

	/// Sets the logging level for the network client.
	/// - Parameter level: The `Logger.Level` to be used for logging messages.
	/// - Returns: An instance of `NetworkClient` configured with the specified logging level.
	func log(level: Logger.Level) -> NetworkClient {
		configs(\.logLevel, level)
	}
}

public extension NetworkClient.Configs {

	/// The logging level used for network operations.
	/// Gets the currently set `Logger.Level`, or `.critical` if not set.
	/// Sets a new `Logger.Level` for logging.
	var logLevel: Logger.Level {
		get { self[\.logLevel] ?? .critical }
		set { self[\.logLevel] = newValue }
	}

	/// The logger used for network operations, configured with the current `logLevel`.
	/// - Returns: A `Logger` instance configured with the appropriate log level.
	var logger: Logger {
		var result = _logger
		result.logLevel = logLevel
		return result
	}
}

private let _logger = Logger(label: "swift-networking")
