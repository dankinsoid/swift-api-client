import Foundation
import HTTPTypes
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

	/// Sets the headers that should be masked in logs.
	/// - Parameter headers: A `Set<HTTPField.Name>` containing the names of headers to be masked.
	func logMaskedHeaders(_ headers: Set<HTTPField.Name>) -> APIClient {
		configs { configs in
			configs.logMaskedHeaders.formUnion(headers)
		}
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

	/// The headers that should be masked in logs.
	/// - Returns: A `Set<HTTPField.Name>` containing the names of headers to be masked.
	var logMaskedHeaders: Set<HTTPField.Name> {
		get { self[\.logMaskedHeaders] ?? .defaultMaskedHeaders }
		set { self[\.logMaskedHeaders] = newValue }
	}
}

public extension APIClient.Configs {

	internal var _errorLogLevel: Logger.Level {
		errorLogLevel ?? logLevel
	}

	internal var _errorLoggingComponents: LoggingComponents {
		errorLogginComponents ?? loggingComponents
	}

	func logRequestStarted(_ request: HTTPRequestComponents, uuid: UUID) {
		if loggingComponents.contains(.onRequest), loggingComponents != .onRequest {
			let message = loggingComponents.requestMessage(for: request, uuid: uuid, maskedHeaders: logMaskedHeaders, fileIDLine: fileIDLine)
			logger.log(level: logLevel, "\(message)")
		}
		if reportMetrics {
			updateTotalRequestsMetrics(for: request)
		}
		listener.onRequestStarted(id: uuid, request: request, configs: self)
	}

	func logRequestFailed(
		_ request: HTTPRequestComponents?,
		response: HTTPResponse?,
		data: Data?,
		start: Date,
		uuid: UUID,
		error: Error
	) -> Error {
		let duration = Date().timeIntervalSince(start)
		if !_errorLoggingComponents.isEmpty {
			let message = _errorLoggingComponents.errorMessage(
				uuid: uuid,
				error: error,
				request: request,
				duration: duration,
				maskedHeaders: logMaskedHeaders,
				fileIDLine: fileIDLine
			)
			logger.log(level: _errorLogLevel, "\(message)")
		}
		if reportMetrics {
			updateHTTPMetrics(for: request, status: response?.status, duration: duration, successful: false)
		}
		let finalError: Error
		do {
			try errorHandler(
				error,
				self,
				APIErrorContext(
					request: request,
					response: data,
					status: response?.status,
					fileIDLine: fileIDLine ?? FileIDLine()
				)
			)
			finalError = error
		} catch {
			finalError = error
		}
		listener.onRequestFailed(id: uuid, error: finalError, configs: self)
		return finalError
	}

	func logRequestCompleted(
		_ request: HTTPRequestComponents,
		response: HTTPResponse?,
		data: Data?,
		uuid: UUID,
		start: Date
	) {
		let duration = Date().timeIntervalSince(start)
		if !loggingComponents.isEmpty {
			let message = loggingComponents.responseMessage(
				for: response,
				uuid: uuid,
				request: request,
				data: data,
				duration: duration,
				maskedHeaders: logMaskedHeaders,
				fileIDLine: fileIDLine
			)
			logger.log(level: logLevel, "\(message)")
		}
		if reportMetrics {
			updateHTTPMetrics(for: request, status: response?.status, duration: duration, successful: true)
		}
		listener.onRequestCompleted(id: uuid, configs: self)
	}
}

public extension Set<HTTPField.Name> {

	static var defaultMaskedHeaders: Set<HTTPField.Name> = [
		.authorization,
		.authenticationInfo,
		.proxyAuthorization,
		.proxyAuthenticationInfo,
		HTTPField.Name("Authentication")!,
		HTTPField.Name("Proxy-Authentication")!,
		HTTPField.Name("X-API-Key")!,
		HTTPField.Name("Api-Key")!,
		HTTPField.Name("X-Auth-Token")!,
		.cookie,
		.setCookie,
		HTTPField.Name("Client-Secret")!,
	]
}

private let defaultLogger = Logger(label: "swift-api-client")
