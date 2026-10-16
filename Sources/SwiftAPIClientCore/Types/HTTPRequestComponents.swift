@preconcurrency import Foundation
import HTTPTypes

/// The components of an HTTP request.
public struct HTTPRequestComponents: Sendable, Hashable {

	/// The URL components of the request.
	public var urlComponents: URLComponents
	/// The HTTP method of the request.
	public var method: HTTPRequest.Method
	/// The headers of the request.
	public var headers: HTTPFields
	/// The body of the request.
	public var body: RequestBody?

	/// The URL of the request.
	public var url: URL? {
		get { urlComponents.url }
		set {
			urlComponents = newValue.flatMap {
				URLComponents(url: $0, resolvingAgainstBaseURL: false)
			} ?? URLComponents()
		}
	}

	/// The request object created from the components.
	public var request: HTTPRequest? {
		url.map {
			HTTPRequest(
				method: method,
				url: $0,
				headerFields: headers
			)
		}
	}

	/// Initialize a new `HTTPRequestComponents` instance from the given URL string.
	/// - Parameters:
	///   - string: The URL string of the request.
	///   - method: The HTTP method of the request.
	///   - headers: The headers of the request.
	///   - body: The body of the request.
	/// - Returns: A new instance of `HTTPRequestComponents` if the URL string is valid. Otherwise, `nil`.
	public init?(
		string: String,
		method: HTTPRequest.Method = .get,
		headers: HTTPFields = [:],
		body: RequestBody? = nil
	) {
		guard let components = URLComponents(string: string) else {
			return nil
		}
		self.init(urlComponents: components, method: method, headers: headers, body: body)
	}

	/// Initialize a new `HTTPRequestComponents` instance from the given URL components.
	/// - Parameters:
	///   - urlComponents: The URL components of the request.
	///   - method: The HTTP method of the request.
	///   - headers: The headers of the request.
	///   - body: The body of the request.
	public init(
		urlComponents: URLComponents = URLComponents(),
		method: HTTPRequest.Method = .get,
		headers: HTTPFields = [:],
		body: RequestBody? = nil
	) {
		self.urlComponents = urlComponents
		self.method = method
		self.headers = headers
		self.body = body
	}

	/// Initialize a new `HTTPRequestComponents` instance from the given URL.
	/// - Parameters:
	///   - url: The URL of the request.
	///   - method: The HTTP method of the request.
	///   - headers: The headers of the request.
	///   - body: The body of the request.
	public init(
		url: URL?,
		method: HTTPRequest.Method = .get,
		headers: HTTPFields = [:],
		body: RequestBody? = nil
	) {
		if let url, let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
			self.init(urlComponents: urlComponents, method: method, headers: headers, body: body)
		} else if let url {
			#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
			if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
				self.init(
					scheme: url.scheme,
					user: url.user(percentEncoded: false),
					password: url.password(percentEncoded: false),
					host: url.host(percentEncoded: false),
					port: url.port,
					path: url.path(percentEncoded: false),
					query: url.query(percentEncoded: false),
					fragment: url.fragment(percentEncoded: false),
					method: method,
					headers: headers,
					body: body
				)
			} else {
				self.init(
					scheme: url.scheme,
					user: url.user,
					password: url.password,
					host: url.host ?? "",
					port: url.port,
					path: url.path,
					query: url.query,
					fragment: url.fragment,
					percentEncoded: true,
					method: method,
					headers: headers,
					body: body
				)
			}
			#else
			self.init(
				scheme: url.scheme,
				user: url.user,
				password: url.password,
				host: url.host,
				port: url.port,
				path: url.path,
				query: url.query,
				fragment: url.fragment,
				percentEncoded: true,
				method: method,
				headers: headers,
				body: body
			)
			#endif
		} else {
			self.init(scheme: nil, host: nil, query: nil)
		}
	}

	/// Initialize a new `HTTPRequestComponents` instance from the given components.
	/// - Parameters:
	///   - scheme: The scheme of the URL.
	///   - user: The user component of the URL.
	///   - password: The password component of the URL.
	///   - host: The host component of the URL.
	///   - port: The port component of the URL.
	///   - path: The path component of the URL.
	///   - query: The query component of the URL.
	///   - fragment: The fragment component of the URL.
	///   - percentEncoded: Whether the components are percent encoded.
	///   - method: The method of the request.
	///   - headers: The headers of the request.
	///   - body: The body of the request.
	///
	/// - Warning: IETF STD 66 (rfc3986) says the use of the format “user:password” in the userinfo subcomponent of a URI is deprecated because passing authentication information in clear text has proven to be a security risk.
	public init(
		scheme: String?,
		user: String? = nil,
		password: String? = nil,
		host: String?,
		port: Int? = nil,
		path: String = "/",
		query: String?,
		fragment: String? = nil,
		percentEncoded: Bool = false,
		method: HTTPRequest.Method = .get,
		headers: HTTPFields = [:],
		body: RequestBody? = nil
	) {
		var urlComponents = URLComponents()
		urlComponents.scheme = scheme
		urlComponents.port = port
		if percentEncoded {
			urlComponents.percentEncodedUser = user
			urlComponents.percentEncodedPassword = password
			#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
			if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
				urlComponents.encodedHost = host
			} else {
				urlComponents.percentEncodedHost = host
			}
			#else
			urlComponents.percentEncodedHost = host
			#endif
			urlComponents.percentEncodedPath = path
			urlComponents.percentEncodedQuery = query
			urlComponents.percentEncodedFragment = fragment
		} else {
			urlComponents.user = user
			urlComponents.password = password
			urlComponents.host = host
			urlComponents.path = path
			urlComponents.query = query
			urlComponents.fragment = fragment
		}
		self.init(urlComponents: urlComponents, method: method, headers: headers, body: body)
	}

	public init(httpRequest: HTTPRequest) {
		self.init(
			url: httpRequest.url,
			method: httpRequest.method,
			headers: httpRequest.headerFields
		)
	}

	public init?(urlRequest: URLRequest) {
		guard urlRequest.httpBodyStream == nil, let httpRequest = urlRequest.httpRequest else {
			return nil
		}
		self.init(
			url: urlRequest.url,
			method: httpRequest.method,
			headers: httpRequest.headerFields,
			body: urlRequest.httpBody.map { .data($0) }
		)
	}

	public mutating func appendPath(
		_ pathComponent: String,
		percentEncoded: Bool = false
	) {
		urlComponents.appendPath(pathComponent, percentEncoded: percentEncoded)
	}

	public mutating func prependPath(
		_ pathComponent: String,
		percentEncoded: Bool = false
	) {
		urlComponents.prependPath(pathComponent, percentEncoded: percentEncoded)
	}

	mutating func addQueryItems(
		items: [URLQueryItem],
		percentEncoded: Bool
	) {
		urlComponents.addQueryItems(items: items, percentEncoded: percentEncoded)
	}
}

public extension URLComponents {

	mutating func appendPath(
		_ pathComponent: String,
		percentEncoded: Bool = false
	) {
		var (path, query, fragment) = decomposePathIfNeeded(pathComponent)
		if path.hasPrefix("/"), self.path.hasSuffix("/") {
			path.removeFirst()
		} else if !path.hasPrefix("/"), !self.path.hasSuffix("/") {
			path = "/" + path
		}
		if percentEncoded {
			percentEncodedPath += path
		} else {
			self.path += path
		}
		if !query.isEmpty {
			addQueryItems(items: query, percentEncoded: percentEncoded)
		}
		if let fragment {
			self.fragment = fragment
		}
	}

	mutating func prependPath(
		_ pathComponent: String,
		percentEncoded: Bool = false
	) {
		var (path, query, fragment) = decomposePathIfNeeded(pathComponent)
		if path.hasSuffix("/"), self.path.hasPrefix("/") {
			path.removeLast()
		} else if !path.hasSuffix("/"), !self.path.hasPrefix("/") {
			path += "/"
		}
		if percentEncoded {
			percentEncodedPath = path + percentEncodedPath
		} else {
			self.path = path + self.path
		}
		if !query.isEmpty {
			addQueryItems(items: query, percentEncoded: percentEncoded)
		}
		if let fragment {
			self.fragment = fragment
		}
	}

	internal mutating func addQueryItems(
		items: [URLQueryItem],
		percentEncoded: Bool
	) {
		guard !items.isEmpty else { return }
		let itemsToAdd: [URLQueryItem]
		if percentEncoded {
			itemsToAdd = items
		} else {
			itemsToAdd = items.map {
				URLQueryItem(
					name: $0.name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? $0.name,
					value: $0.value?.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowedRFC3986) ?? $0.value
				)
			}
		}
		percentEncodedQueryItems = (percentEncodedQueryItems ?? []) + itemsToAdd
	}
}

private func decomposePathIfNeeded(_ path: String) -> (String, query: [URLQueryItem], fragment: String?) {
	var path = path
	var query: [URLQueryItem] = []
	var fragment: String?
	if let fragmentIndex = path.lastIndex(of: "#") {
		fragment = String(path[path.index(after: fragmentIndex)...])
		path = String(path[..<fragmentIndex])
	}
	if let queryIndex = path.lastIndex(of: "?") {
		query = path[queryIndex...].dropFirst().components(separatedBy: "&").compactMap {
			let components = $0.components(separatedBy: "=")
			guard !components.isEmpty else { return nil }
			return URLQueryItem(name: components[0], value: components.dropFirst().last)
		}
		path = String(path[..<queryIndex])
	}
	return (path, query: query, fragment: fragment)
}

public extension HTTPRequestComponents {

  /// Returns an `URLRequest` object created from the components.
	var urlRequest: URLRequest? {
		guard let url, let request, var result = URLRequest(httpRequest: request) else { return nil }
		result.url = url
		switch body {
		case let .data(data):
			result.httpBody = data
		case let .file(url):
			result.httpBodyStream = InputStream(url: url)
		case .none:
			break
		}
		return result
	}
}

public extension HTTPRequestComponents {

		/// Returns a cURL command string representation of the request
		var cURL: String {
			cURL(maskedHeaders: [])
		}

    /// Returns a cURL command string representation of the request
		func cURL(maskedHeaders: Set<HTTPField.Name>) -> String {
        var components: [String] = []

        // Add URL
        if let url {
            let urlString = url.absoluteString.replacingOccurrences(of: "\"", with: "\\\"") // Escape double quotes
            components.append("\"\(urlString)\"")
        }

        // Add method if not GET
        if method != .get {
            components.append("-X \(method.rawValue)")
        }

        // Add headers
        for field in headers {
            let headerValue = field.value.replacingOccurrences(of: "\"", with: "\\\"") // Escape double quotes
						components.append("-H \"\(field.name.rawName): \(maskedHeaders.contains(field.name) ? "***" : headerValue)\"")
        }

        // Add body if present (support multiple -d flags)
        if case let .data(data) = body, let bodyString = String(data: data, encoding: .utf8) {
            let escapedBody = bodyString.replacingOccurrences(of: "\"", with: "\\\"") // Escape double quotes
            let bodyParts = escapedBody.split(separator: "&").map { "-d \"\($0)\"" } // Handle multiple -d flags
            components.append(contentsOf: bodyParts)
        } else if case let .file(url) = body {
            let filePath = url.path.replacingOccurrences(of: "\"", with: "\\\"") // Escape double quotes
            components.append("--data-binary @\"\(filePath)\"")
        }

        return "curl " + components.joined(separator: " \\\n    ")
    }

    /// Initialize from a cURL command string
    init(cURL: String) throws {
        // Ensure it's a valid cURL command
        guard cURL.range(of: curlPattern, options: .regularExpression) != nil else {
            throw Errors.custom("Invalid cURL command: \(cURL)")
        }

        // Extract URL (handle cases where it's not the first argument)
        guard let urlMatch = cURL.firstMatch(for: urlPattern),
              let urlString = urlMatch[1] ?? urlMatch[2] ?? urlMatch[3],
              let url = URL(string: urlString)
        else {
            throw Errors.custom("Could not parse URL from cURL command: \(cURL)")
        }

        // Extract method (support `-XPOST` without space)
        var method = HTTPRequest.Method.get
        if let methodMatch = cURL.firstMatch(for: #"-X\s?(\w+)"#) {
            method = HTTPRequest.Method(rawValue: methodMatch[1] ?? "GET") ?? .get
        }

        // Extract headers
        var headers = HTTPFields()
        for headerMatch in cURL.matches(for: headerPattern) {
            if let headerString = headerMatch[1] ?? headerMatch[2] ?? headerMatch[3] {
                let components = headerString.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
                if components.count == 2 {
                    let name = components[0].trimmingCharacters(in: .whitespaces)
                    let value = components[1].trimmingCharacters(in: .whitespaces)
                    headers[.init(name)!] = value
                }
            }
        }

        // Extract body (support multiple -d flags)
        let dataMatches = cURL.matches(for: dataPattern).compactMap { $0[1] ?? $0[2] ?? $0[3] }
        var body: RequestBody? = nil
        if !dataMatches.isEmpty {
            let joinedData = dataMatches.joined(separator: "&") // Combine multiple -d flags
            body = .data(joinedData.data(using: .utf8) ?? Data())
        }

        self.init(url: url, method: method, headers: headers, body: body)
    }
}

/// Regular expression pattern to match cURL command components
private let curlPattern = #"(?:^|\s)curl\s+(?:'[^']*'|"[^"]*"|\S+)(?:\s+-\w+\s?(?:'[^']*'|"[^"]*"|\S+))*"#

/// Regular expression pattern to match URL in cURL command (allow URL anywhere in the command)
private let urlPattern = #"(?:\s+|^)['\"]?(https?://[^\s'\"\\]+)['\"]?"#

/// Regular expression pattern to match headers in cURL command
private let headerPattern = #"(?:-H\s+|--header\s+)(?:'([^']+:\s*[^']*)'|"([^"]+:\s*[^"]*)"|([^\s'"]+:\s*[^\s'"]+))"#

/// Regular expression pattern to match data in cURL command (support multiple `-d`)
private let dataPattern = #"(?:-d\s+|--data(?:-ascii|-binary|-raw|-urlencode)?\s?)(?:'([^']*)'|"([^"]*)"|([^\s'"]+))"#
