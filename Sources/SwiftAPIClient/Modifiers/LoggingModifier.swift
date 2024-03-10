import Foundation
import Logging

public extension APIClient {

	/// Sets the custom logger.
	/// - Parameter logger: The `Logger` to be used for logging messages.
	/// - Returns: An instance of `APIClient` configured with the specified logging level.
	func logger(_ logger: Logger) -> APIClient {
		configs(\.logger, logger)
	}

	/// Sets the logging level for the logger.
	/// - Parameter level: The `Logger.Level` to be used for logging messages.
	/// - Returns: An instance of `APIClient` configured with the specified logging level.
	func log(level: Logger.Level) -> APIClient {
		configs(\.logLevel, level)
	}

	/// Sets the components to be logged.
	func loggingComponents(_ components: LoggingComponents) -> APIClient {
		configs(\.loggingComponents, components)
	}
}

public extension APIClient.Configs {

	/// The logger used for network operations.
	/// - Returns: A `Logger` instance configured with the appropriate log level.
	var logger: Logger {
		get { self[\.logger] ?? defaultLogger }
		set { self[\.logger] = newValue }
	}

	/// The log level to be used for logs.
	/// - Returns: A `Logger.Level` used in logs.
	var logLevel: Logger.Level {
		get { self[\.logLevel] ?? .info }
		set { self[\.logLevel] = newValue }
	}

	/// The components to be logged.
	/// - Returns: A `LoggingComponents` instance configured with the appropriate components.
	var loggingComponents: LoggingComponents {
		get { self[\.loggingComponents] ?? .standart }
		set { self[\.loggingComponents] = newValue }
	}
}

private let defaultLogger = Logger(label: "swift-api-client")
