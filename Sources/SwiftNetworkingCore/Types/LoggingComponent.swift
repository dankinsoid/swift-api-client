import Foundation

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

    public static var url: LoggingComponents { [.path, .baseURL, .query] }

    /// Logs request and response lines.
    ///
    /// Example:
    /// ```
    /// --> POST /greeting (3-byte body)
    ///
    /// <-- ✅ 200 OK (22ms, 6-byte body)
    /// ```
    public static var basic: LoggingComponents { [.method, .path, .query, .bodySize, .duration, .statusCode] }
    public static var standart: LoggingComponents { [.basic, .headers, .location, .uuid] }
    public static var full: LoggingComponents { [.standart, .baseURL, .body] }

    public var rawValue: UInt16

    public init(rawValue: UInt16) {
        self.rawValue = rawValue
    }
}

extension LoggingComponents {

    public func message(
        uuid: UUID,
        request: URLRequest,
        response: HTTPURLResponse,
        data: Data?,
        duration: TimeInterval,
        fileIDLine: FileIDLine,
        colorize: Bool = false
    ) -> String {
        guard !isEmpty else { return "" }
        let rqstMsg = requestMessage(for: request, uuid: uuid, fileIDLine: fileIDLine, colorize: colorize)
        let rspnMsg = subtracting(.uuid).responseMessage(for: response, uuid: uuid, data: data, duration: duration, colorize: colorize)
        return "\(rqstMsg)\n\n\(rspnMsg)"
    }

    public func requestMessage(
        for request: URLRequest,
        uuid: UUID,
        fileIDLine: FileIDLine,
        colorize: Bool = false
    ) -> String {
        guard !isEmpty else { return "" }
        var message = "--> 🌐"
        var isMultiline = false
        if contains(.location) {
            message = "\(fileIDLine.fileID)/\(fileIDLine.line)\n" + message
        }
        if contains(.uuid) {
            message = "[\(uuid.uuidString)]\(contains(.location) ? " " : "\n")" + message
        }
        if contains(.method) {
            message += " \(request.httpMethod ?? "GET")"
        }
        if let url = request.url, !intersection(.url).isEmpty {
            message += " \(urlString(url))"
        }
        if contains(.bodySize), let body = request.httpBody {
            message += " (\(body.count)-byte body)"
        }
        if contains(.headers), request.allHTTPHeaderFields?.isEmpty == false {
            message += "\n\(request.headers.multilineDescription)"
            isMultiline = true
        }
        if contains(.body), let body = request.httpBody, let bodyString = String(data: body, encoding: .utf8) {
            message += "\n\(bodyString)"
            isMultiline = true
        }
        if isMultiline {
            message += "\n--> END"
            if contains(.method) {
                message += " \(request.httpMethod ?? "GET")"
            }
        }
        return message
    }

    public func responseMessage(
        for response: HTTPURLResponse,
        uuid: UUID,
        data: Data?,
        duration: TimeInterval,
        colorize: Bool = false
    ) -> String {
        guard !isEmpty else { return "" }
        var message = "<-- "
        if contains(.uuid) {
            message = "[\(uuid.uuidString)]\n" + message
        }
        if response.httpStatusCode.isSuccess {
            message.append("✅")
        } else {
            message.append("🛑")
        }
        var isMultiline = false
        if contains(.statusCode) {
            let string = "\(response.statusCode) \(response.httpStatusCode.name)"
            message += " \(colorize ? string.consoleStyle(response.httpStatusCode.isSuccess ? .success : .error) : string)"
        }
        var inBrackets: [String] = []
        if contains(.bodySize), let data = data {
            inBrackets.append("\(data.count)-byte body")
        }
        if contains(.duration) {
            inBrackets.append("\(Int(duration * 1000))ms")
        }
        if !inBrackets.isEmpty {
            message += " (\(inBrackets.joined(separator: ", ")))"
        }
    
        if contains(.headers), !response.allHeaderFields.isEmpty {
            message += "\n\(response.headers.multilineDescription)"
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
            result =  String(url.absoluteString.dropFirst(baseURL.count))
        } else if contains(.query) {
            result = String(url.absoluteString.components(separatedBy: "?").dropFirst().joined(separator: "?"))
        } else {
            result = components.path
        }
        return "/" + result.trimmingCharacters(in: ["/"])
    }
}

private extension HTTPHeaders {
    
    var multilineDescription: String {
        headers
            .sorted(by: { $0.name.rawValue < $1.name.rawValue })
            .map { "\($0.name): \($0.value)" }
            .joined(separator: "\n")
    }
}
