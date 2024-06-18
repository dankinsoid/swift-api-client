import Foundation

public extension APIClient {

	/// Sets the error handler.
	func errorHandler(_ handler: @escaping (Error, APIClient.Configs, APIErrorContext) throws -> Void) -> APIClient {
		configs { configs in
			let current = configs.errorHandler
			configs.errorHandler = { failure, configs, context in
				do {
					try current(failure, configs, context)
				} catch {
					try handler(error, configs, context)
					throw error
				}
			}
		}
	}

	/// Sets the error handler to throw an `APIClientError` with detailed information.
	func detailedError(includeBody: APIClientError.IncludeBodyPolicy = .auto) -> APIClient {
		errorHandler { error, configs, context in
			if error is APIClientError {
				throw error
			} else {
				throw APIClientError(error: error, configs: configs, context: context, includeBody: includeBody)
			}
		}
	}
}

public extension APIClient.Configs {

	var errorHandler: (Error, APIClient.Configs, APIErrorContext) throws -> Void {
		get { self[\.errorHandler] ?? { _, _, _ in } }
		set { self[\.errorHandler] = newValue }
	}
}

public struct APIErrorContext: Equatable {

	public var request: HTTPRequestComponents?
	public var response: Data?
	public var status: HTTPResponse.Status?
	public var fileID: String
	public var line: UInt

	public init(
		request: HTTPRequestComponents? = nil,
		response: Data? = nil,
		status: HTTPResponse.Status? = nil,
		fileID: String,
		line: UInt
	) {
		self.request = request
		self.response = response
		self.status = status
		self.fileID = fileID
		self.line = line
	}

	public init(
		request: HTTPRequestComponents? = nil,
		response: Data? = nil,
		status: HTTPResponse.Status? = nil,
		fileIDLine: FileIDLine
	) {
		self.init(
			request: request,
			response: response,
			status: status,
			fileID: fileIDLine.fileID,
			line: fileIDLine.line
		)
	}
}

public struct APIClientError: LocalizedError, CustomStringConvertible {

	public var error: Error
	public var configs: APIClient.Configs
	public var context: APIErrorContext
	public var includeBody: IncludeBodyPolicy

	public init(error: Error, configs: APIClient.Configs, context: APIErrorContext, includeBody: IncludeBodyPolicy) {
		self.error = error
		self.configs = configs
		self.context = context
		self.includeBody = includeBody
	}

	public var errorDescription: String? {
		description
	}

	public var description: String {
		var components = [error.humanReadable]

		if let request = context.request {
			let urlString = request.urlComponents.url?.absoluteString ?? request.urlComponents.path
			components.append("Request: \(request.method) \(urlString)")
		}
		if let response = context.response {
			switch includeBody {
			case .never:
				break
			case .always:
				if let utf8 = String(data: response, encoding: .utf8) {
					components.append("Response: \(utf8)")
				}
			case let .auto(sizeLimit):
				if response.count < sizeLimit, let utf8 = String(data: response, encoding: .utf8) {
					components.append("Response: \(utf8)")
				}
			}
		}
		components.append("File: \(context.fileID) Line: \(context.line)")
		return components.joined(separator: " - ")
	}

	public enum IncludeBodyPolicy {

		case never
		case always
		case auto(sizeLimit: Int)

		public static var auto: IncludeBodyPolicy { .auto(sizeLimit: 1024) }
	}
}
