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
        url: URL,
        method: HTTPRequest.Method = .get,
        headers: HTTPFields = [:],
        body: RequestBody? = nil
    ) {
        if let urlComponents = URLComponents(url: url, resolvingAgainstBaseURL: false) {
            self.init(urlComponents: urlComponents, method: method, headers: headers, body: body)
        } else {
#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
            if #available(macOS 13.0, iOS 16.0, tvOS 16.0, watchOS 9.0, *) {
                self.init(
                    scheme: url.scheme ?? "https",
                    user: url.user(percentEncoded: false),
                    password: url.password(percentEncoded: false),
                    host: url.host(percentEncoded: false) ?? "",
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
                    scheme: url.scheme ?? "https",
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
            scheme: url.scheme ?? "https",
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
#endif
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
        scheme: String,
        user: String? = nil,
        password: String? = nil,
        host: String,
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

    public mutating func appendPath(
        _ pathComponent: String,
        percentEncoded: Bool = false
    ) {
        var path = pathComponent
        if path.hasPrefix("/"), urlComponents.path.hasSuffix("/") {
            path.removeFirst()
        } else if !path.hasPrefix("/"), !urlComponents.path.hasSuffix("/") {
            path = "/" + path
        }
        if percentEncoded {
            urlComponents.percentEncodedPath += path
        } else {
            urlComponents.path += path
        }
        if !urlComponents.path.isEmpty, !urlComponents.path.hasSuffix("/") {
            urlComponents.path += "/"
        }
    }
}

extension HTTPRequestComponents {

    public var urlRequest: URLRequest? {
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
