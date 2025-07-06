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

	/// Sets the logging level for error logs.
	/// - Parameter level: The `Logger.Level` to be used for error logs. When `nil`, `logLevel` is used.
	/// - Returns: An instance of `APIClient` configured with the specified error logging level.
	func errorLog(level: Logger.Level?) -> APIClient {
		configs(\.errorLogLevel, level)
	}

	/// Sets the components to be logged.
	func loggingComponents(_ components: LoggingComponents) -> APIClient {
		configs(\.loggingComponents, components)
	}

	/// Sets the components to be logged for error logs.
	/// - Parameter components: The `LoggingComponents` to be used for error logs. When `nil`, `loggingComponents` is used.
	/// - Returns: An instance of `APIClient` configured with the specified error logging components.
	func errorLoggingComponents(_ components: LoggingComponents?) -> APIClient {
		configs(\.errorLogginComponents, components)
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

	/// The log level to be used for error logs.
	/// - Returns: A `Logger.Level` used in error logs.
	var errorLogLevel: Logger.Level? {
		get { self[\.errorLogLevel] ?? nil }
		set { self[\.errorLogLevel] = newValue }
	}

	/// The components to be logged.
	/// - Returns: A `LoggingComponents` instance configured with the appropriate components.
	var loggingComponents: LoggingComponents {
		get { self[\.loggingComponents] ?? .standart }
		set { self[\.loggingComponents] = newValue }
	}

	/// The components to be logged for error logs.
	/// - Returns: A `LoggingComponents` instance configured with the appropriate components.
	var errorLogginComponents: LoggingComponents? {
		get { self[\.errorLogginComponents] ?? nil }
		set { self[\.errorLogginComponents] = newValue }
	}
}

extension APIClient.Configs {

	var _errorLogLevel: Logger.Level {
		errorLogLevel ?? logLevel
	}

	var _errorLoggingComponents: LoggingComponents {
		errorLogginComponents ?? loggingComponents
	}

	func logRequest(_ request: HTTPRequestComponents, uuid: UUID) {
		if loggingComponents.contains(.onRequest), loggingComponents != .onRequest {
			let message = loggingComponents.requestMessage(for: request, uuid: uuid, fileIDLine: fileIDLine)
			logger.log(level: logLevel, "\(message)")
		}
		#if canImport(Metrics)
		if reportMetrics {
			updateTotalRequestsMetrics(for: request)
		}
		#endif
	}
}

private let defaultLogger = Logger(label: "swift-api-client")
