import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes

/// The components to be logged.
public struct LoggingComponents: OptionSet {

	public static let method = LoggingComponents(rawValue: 1 << 0)
	public static let path = LoggingComponents(rawValue: 1 << 1)
	public static let headers = LoggingComponents(rawValue: 1 << 2)
	public static let body = LoggingComponents(rawValue: 1 << 3)
	public static let bodySize = LoggingComponents(rawValue: 1 << 4)
	public static let duration = LoggingComponents(rawValue: 1 << 5)
	public static let statusCode = LoggingComponents(rawValue: 1 << 6)
	public static let baseURL = LoggingComponents(rawValue: 1 << 7)
	public static let query = LoggingComponents(rawValue: 1 << 8)
	public static let uuid = LoggingComponents(rawValue: 1 << 9)
	public static let location = LoggingComponents(rawValue: 1 << 10)
	public static let onRequest = LoggingComponents(rawValue: 1 << 11)
	public static let cURL = LoggingComponents(rawValue: 1 << 12)

	public static var url: LoggingComponents { [.path, .baseURL, .query] }

	/// Short log without body, headers, base URL, call location and uuid.
	///
	/// Example:
	/// ```
	/// --> POST /greeting (3-byte body)
	/// <-- ✅ 200 OK (22ms, 6-byte body) /greeting
	/// ```
	public static var basic: LoggingComponents { [.method, .path, .query, .bodySize, .duration, .statusCode] }

	/// Standart log without body and  base URL.
	///
	/// Example:
	/// ```
	/// [29CDD5AE-1A5D-4135-B76E-52A8973985E4] ModuleName/FileName.swift/72
	/// --> 🌐 PUT /petstore (9-byte body)
	/// Content-Type: application/json
	/// --> END PUT
	/// [29CDD5AE-1A5D-4135-B76E-52A8973985E4]
	/// <-- ✅ 200 OK (0ms, 15-byte body) /petstore
	/// ```
	public static var standart: LoggingComponents { [.basic, .headers, .location, .uuid] }

	/// Full log.
	/// Example:
	/// ```
	/// [9F252BDC-1F9E-4F3D-8C46-1F984C10F4EB] ModuleName/FileName.swift/72
	/// --> 🌐 PUT https://example.com/petstore (45-byte body)
	/// Content-Type: application/json
	/// {"id":"666A6886-70C4-454C-BD2D-F36B1B2F7F95"}
	/// --> END PUT
	/// [9F252BDC-1F9E-4F3D-8C46-1F984C10F4EB]
	/// <-- ✅ 200 OK (0ms, 17-byte body) https://example.com/petstore
	/// {"name": "Candy"}
	/// <-- END
	/// ```
	public static var full: LoggingComponents { [.standart, .baseURL, .body] }

	public var rawValue: UInt16

	public init(rawValue: UInt16) {
		self.rawValue = rawValue
	}
}

public extension LoggingComponents {

	@available(*, deprecated, renamed: "requestMessage(for:uuid:maskedHeaders:codeLocation:)")
	func requestMessage(
		for request: HTTPRequestComponents,
		uuid: UUID,
		maskedHeaders: Set<HTTPField.Name>,
		fileIDLine: CodeLocation?
	) -> String {
		requestMessage(
			for: request,
			uuid: uuid,
			maskedHeaders: maskedHeaders,
			codeLocation: fileIDLine
		)
	}
	
	func requestMessage(
		for request: HTTPRequestComponents,
		uuid: UUID,
		maskedHeaders: Set<HTTPField.Name>,
		codeLocation: CodeLocation?
	) -> String {
		guard !isEmpty else { return "" }
		var message = "--> 🌐"
		var isMultiline = false
		if contains(.location), let codeLocation {
			message = "\(codeLocation.fileID)/\(codeLocation.line)\n" + message
		}
		if contains(.uuid) {
			message = "[\(uuid.uuidString)]\(contains(.location) ? " " : "\n")" + message
		}
		if contains(.method) {
			message += " \(request.method.rawValue)"
		}
		if let url = request.url, !intersection(.url).isEmpty {
			message += " \(urlString(url))"
		}
		if contains(.bodySize), let body = request.body?.data {
			message += " (\(body.count)-byte body)"
		}
		if contains(.headers), !request.headers.isEmpty {
			message += "\n\(request.headers.multilineDescription(masked: maskedHeaders))"
			isMultiline = true
		}
		if contains(.body), let body = request.body?.data, let bodyString = String(data: body, encoding: .utf8) {
			message += "\n\(bodyString)"
			isMultiline = true
		}
		if contains(.body), let body = request.body?.fileURL {
			message += "\n\(body.relativePath)"
			isMultiline = true
		}
		if contains(.cURL) {
			message += "\n\(request.cURL(maskedHeaders: maskedHeaders))"
			isMultiline = true
		}
		if isMultiline {
			message += "\n--> END"
			if contains(.method) {
				message += " \(request.method.rawValue)"
			}
		}
		return message
	}

	@available(*, deprecated, renamed: "responseMessage(for:uuid:request:data:duration:error:maskedHeaders:codeLocation:)")
	func responseMessage(
		for response: HTTPResponse?,
		uuid: UUID,
		request: HTTPRequestComponents? = nil,
		data: Data?,
		duration: TimeInterval,
		error: Error? = nil,
		maskedHeaders: Set<HTTPField.Name>,
		fileIDLine: CodeLocation?
	) -> String {
		responseMessage(
			uuid: uuid,
			request: request,
			statusCode: response?.status,
			data: data,
			headers: response?.headerFields ?? [:],
			duration: duration,
			error: error,
			maskedHeaders: maskedHeaders,
			codeLocation: fileIDLine
		)
	}
	
	func responseMessage(
		for response: HTTPResponse?,
		uuid: UUID,
		request: HTTPRequestComponents? = nil,
		data: Data?,
		duration: TimeInterval,
		error: Error? = nil,
		maskedHeaders: Set<HTTPField.Name>,
		codeLocation: CodeLocation?
	) -> String {
		responseMessage(
			uuid: uuid,
			request: request,
			statusCode: response?.status,
			data: data,
			headers: response?.headerFields ?? [:],
			duration: duration,
			error: error,
			maskedHeaders: maskedHeaders,
			codeLocation: codeLocation
		)
	}

	@available(*, deprecated, renamed: "responseMessage(uuid:request:statusCode:data:headers:duration:error:maskedHeaders:codeLocation:)")
	func responseMessage(
		uuid: UUID,
		request: HTTPRequestComponents? = nil,
		statusCode: HTTPResponse.Status? = nil,
		data: Data?,
		headers: HTTPFields = [:],
		duration: TimeInterval? = nil,
		error: Error? = nil,
		maskedHeaders: Set<HTTPField.Name>,
		fileIDLine: CodeLocation?
	) -> String {
		responseMessage(
			uuid: uuid,
			request: request,
			statusCode: statusCode,
			data: data,
			headers: headers,
			duration: duration,
			error: error,
			maskedHeaders: maskedHeaders,
			codeLocation: fileIDLine
		)
	}
	
	func responseMessage(
		uuid: UUID,
		request: HTTPRequestComponents? = nil,
		statusCode: HTTPResponse.Status? = nil,
		data: Data?,
		headers: HTTPFields = [:],
		duration: TimeInterval? = nil,
		error: Error? = nil,
		maskedHeaders: Set<HTTPField.Name>,
		codeLocation: CodeLocation?
	) -> String {
		guard !isEmpty else { return "" }
		var message = "<-- "
		if let request {
				message = requestMessage(for: request, uuid: uuid, maskedHeaders: maskedHeaders, codeLocation: codeLocation) + "\n" + message
		} else {
			if contains(.uuid) {
				message = "[\(uuid.uuidString)]\n" + message
			}
		}
		switch (statusCode?.kind, error) {
		case (_, .some), (.serverError, _), (.clientError, _), (.invalid, _):
			message.append("🛑")
		case (.successful, _), (nil, nil):
			message.append("✅")
		case (.informational, _):
			message.append("ℹ️")
		case (.redirection, _):
			message.append("🔀")
		}
		var isMultiline = false
		if let statusCode, contains(.statusCode) {
			message += " \(statusCode.code) \(statusCode.reasonPhrase)"
		}
		var inBrackets: [String] = []
		if let duration, contains(.duration) {
			inBrackets.append("\(Int(duration * 1000))ms")
		}
		if contains(.bodySize), let data {
			inBrackets.append("\(data.count)-byte body")
		}
		if !inBrackets.isEmpty {
			message += " (\(inBrackets.joined(separator: ", ")))"
		}

		if let error {
			message += "\n❗️\(error.humanReadable)❗️"
			isMultiline = true
		}

		if contains(.headers), !headers.isEmpty {
			message += "\n\(headers.multilineDescription(masked: maskedHeaders))"
			isMultiline = true
		}
		if contains(.body), let body = data, let bodyString = String(data: body, encoding: .utf8) {
			message += "\n\(bodyString)"
			isMultiline = true
		}

		if isMultiline {
			message += "\n<-- END"
		}

		return message
	}

	@available(*, deprecated, renamed: "errorMessage(uuid:error:request:duration:maskedHeaders:codeLocation:)")
	func errorMessage(
		uuid: UUID,
		error: Error,
		request: HTTPRequestComponents? = nil,
		duration: TimeInterval? = nil,
		maskedHeaders: Set<HTTPField.Name>,
		fileIDLine: CodeLocation?
	) -> String {
		errorMessage(
			uuid: uuid,
			error: error,
			request: request,
			duration: duration,
			maskedHeaders: maskedHeaders,
			codeLocation: fileIDLine
		)
	}
	
	func errorMessage(
		uuid: UUID,
		error: Error,
		request: HTTPRequestComponents? = nil,
		duration: TimeInterval? = nil,
		maskedHeaders: Set<HTTPField.Name>,
		codeLocation: CodeLocation? = nil
	) -> String {
		var message = contains(.uuid) && request == nil ? "[\(uuid.uuidString)] " : ""
		if let duration, contains(.duration) {
			message += "\(Int(duration * 1000))ms "
		}

		if let request {
			message = requestMessage(for: request, uuid: uuid, maskedHeaders: maskedHeaders, codeLocation: codeLocation) + "\n" + message
				} else if let codeLocation, contains(.location) {
			message = "\(codeLocation.fileID)/\(codeLocation.line)\n" + message
		}
		message += "❗️\(error.humanReadable)❗️"
		return message
	}

	private func urlString(_ url: URL) -> String {
		if contains(.url) {
			return url.absoluteString
		}
		guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
			return ""
		}
		let baseURL = url.baseURL?.absoluteString ?? "\(components.scheme ?? "https")://\(components.host ?? "")"
		if self == .baseURL {
			return baseURL
		}
		let result: String
		if contains([.query, .path]) {
			result = String(url.absoluteString.dropFirst(baseURL.count))
		} else if contains(.query) {
			result = String(url.absoluteString.components(separatedBy: "?").dropFirst().joined(separator: "?"))
		} else {
			result = components.path
		}
		return "/" + result.trimmingCharacters(in: ["/"])
	}
}

private extension HTTPFields {

	func multilineDescription(masked: Set<HTTPField.Name>) -> String {
		map {
			"\($0.name): \(masked.contains($0.name) ? "***" : $0.value)"
		}
		.joined(separator: "\n")
	}
}
