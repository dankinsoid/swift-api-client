import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// An order-preserving and case-insensitive representation of HTTP headers.
public struct HTTPHeaders {

	public var headers: [HTTPHeader] = []

	/// Creates an empty instance.
	public init() {}

	/// Creates an instance from an array of `HTTPHeader`s. Duplicate case-insensitive names are collapsed into the last
	/// name and value encountered.
	public init(_ headers: [HTTPHeader]) {
		headers.forEach { update($0) }
	}

	/// Creates an instance from a `[HTTPHeader.Key: String]`. Duplicate case-insensitive names are collapsed into the last name
	/// and value encountered.
	public init(_ dictionary: [HTTPHeader.Key: String]) {
		dictionary.forEach { update(HTTPHeader($0.key, $0.value)) }
	}

	/// Creates an instance from a `[String: String]`. Duplicate case-insensitive names are collapsed into the last name
	/// and value encountered.
	public init(_ dictionary: [String: String]) {
		dictionary.forEach { update(HTTPHeader(HTTPHeader.Key($0.key), $0.value)) }
	}

	/// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
	///
	/// - Parameters:
	///   - name:  The `HTTPHeader` name.
	///   - value: The `HTTPHeader value.
	public mutating func add(_ name: HTTPHeader.Key, _ value: String) {
		update(HTTPHeader(name, value))
	}

	/// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
	///
	/// - Parameter header: The `HTTPHeader` to update or append.
	public mutating func add(_ header: HTTPHeader) {
		update(header)
	}

	/// Case-insensitively updates or appends an `HTTPHeader` into the instance using the provided `name` and `value`.
	///
	/// - Parameters:
	///   - name:  The `HTTPHeader` name.
	///   - value: The `HTTPHeader value.
	public mutating func update(_ name: HTTPHeader.Key, _ value: String) {
		update(HTTPHeader(name, value))
	}

	/// Case-insensitively updates or appends the provided `HTTPHeader` into the instance.
	///
	/// - Parameter header: The `HTTPHeader` to update or append.
	public mutating func update(_ header: HTTPHeader) {
		guard let index = headers.index(of: header.name) else {
			headers.append(header)
			return
		}

		headers.replaceSubrange(index ... index, with: [header])
	}

	/// Case-insensitively removes an `HTTPHeader`, if it exists, from the instance.
	///
	/// - Parameter name: The name of the `HTTPHeader` to remove.
	public mutating func remove(_ name: HTTPHeader.Key) {
		guard let index = headers.index(of: name) else { return }

		headers.remove(at: index)
	}

	/// Sort the current instance by header name, case insensitively.
	public mutating func sort() {
		headers.sort { $0.name.rawValue.lowercased() < $1.name.rawValue.lowercased() }
	}

	/// Returns an instance sorted by header name.
	///
	/// - Returns: A copy of the current instance sorted by name.
	public func sorted() -> HTTPHeaders {
		var headers = self
		headers.sort()

		return headers
	}

	/// Case-insensitively find a header's value by name.
	///
	/// - Parameter name: The name of the header to search for, case-insensitively.
	///
	/// - Returns:        The value of header, if it exists.
	public func value(for name: HTTPHeader.Key) -> String? {
		guard let index = headers.index(of: name) else { return nil }

		return headers[index].value
	}

	/// Case-insensitively access the header with the given name.
	///
	/// - Parameter name: The name of the header.
	public subscript(_ name: HTTPHeader.Key) -> String? {
		get { value(for: name) }
		set {
			if let value = newValue {
				update(name, value)
			} else {
				remove(name)
			}
		}
	}

	/// The dictionary representation of all headers.
	///
	/// This representation does not preserve the current order of the instance.
	public var dictionary: [String: String] {
		let namesAndValues = headers.map { ($0.name.rawValue, $0.value) }
		return Dictionary(namesAndValues, uniquingKeysWith: { "\($0), \($1)" })
	}
}

extension HTTPHeaders: ExpressibleByDictionaryLiteral {

	public init(dictionaryLiteral elements: (HTTPHeader.Key, String)...) {
		elements.forEach { update($0.0, $0.1) }
	}
}

extension HTTPHeaders: ExpressibleByArrayLiteral {

	public init(arrayLiteral elements: HTTPHeader...) {
		self.init(elements)
	}
}

extension HTTPHeaders: Sequence {
	public func makeIterator() -> IndexingIterator<[HTTPHeader]> {
		headers.makeIterator()
	}
}

extension HTTPHeaders: Collection {
	public var startIndex: Int {
		headers.startIndex
	}

	public var endIndex: Int {
		headers.endIndex
	}

	public subscript(position: Int) -> HTTPHeader {
		headers[position]
	}

	public func index(after i: Int) -> Int {
		headers.index(after: i)
	}
}

extension HTTPHeaders: CustomStringConvertible {
	public var description: String {
		headers.map(\.description)
			.joined(separator: "\n")
	}
}

// MARK: - HTTPHeader

/// A representation of a single HTTP header's name / value pair.
public struct HTTPHeader: Hashable {

	/// Name of the header.
	public var name: HTTPHeader.Key

	/// Value of the header.
	public var value: String

	/// Creates an instance from the given `name` and `value`.
	///
	/// - Parameters:
	///   - name:  The name of the header.
	///   - value: The value of the header.
	public init(_ name: HTTPHeader.Key, _ value: String) {
		self.name = name
		self.value = value
	}
}

extension HTTPHeader: CustomStringConvertible {

	public var description: String {
		"\(name): \(value)"
	}
}

public extension HTTPHeader {

	/// Returns an `Accept` header.
	///
	/// - Parameter value: The `Accept` value.
	///
	/// - Returns:         The header
	static func accept(_ value: ContentType) -> HTTPHeader {
		HTTPHeader(.accept, value.rawValue)
	}

	/// Returns a `Basic` `Authorization` header using the `username` and `password` provided.
	///
	/// - Parameters:
	///   - username: The username of the header.
	///   - password: The password of the header.
	///
	/// - Returns:    The header.
	static func authorization(username: String, password: String) -> HTTPHeader {
		let credential = Data("\(username):\(password)".utf8).base64EncodedString()

		return authorization("Basic \(credential)")
	}

	/// Returns a `Bearer` `Authorization` header using the `bearerToken` provided
	///
	/// - Parameter bearerToken: The bearer token.
	///
	/// - Returns:               The header.
	static func authorization(bearerToken: String) -> HTTPHeader {
		authorization("Bearer \(bearerToken)")
	}

	/// Returns an `Authorization` header.
	///
	/// Alamofire provides built-in methods to produce `Authorization` headers. For a Basic `Authorization` header use
	/// `HTTPHeader.authorization(username:password:)`. For a Bearer `Authorization` header, use
	/// `HTTPHeader.authorization(bearerToken:)`.
	///
	/// - Parameter value: The `Authorization` value.
	///
	/// - Returns:         The header.
	static func authorization(_ value: String) -> HTTPHeader {
		HTTPHeader(.authorization, value)
	}

	/// Returns a `Content-Disposition` header.
	///
	/// - Parameter value: The `Content-Disposition` value.
	///
	/// - Returns:         The header.
	static func contentDisposition(_ value: String) -> HTTPHeader {
		HTTPHeader(.contentDisposition, value)
	}

	/// Returns a `Content-Encoding` header.
	///
	/// - Parameter value: The `Content-Encoding`.
	///
	/// - Returns:         The header.
	static func contentEncoding(_ value: String) -> HTTPHeader {
		HTTPHeader("Content-Encoding", value)
	}

	/// Returns a `Content-Type` header.
	///
	/// All Alamofire `ParameterEncoding`s and `ParameterEncoder`s set the `Content-Type` of the request, so it may not
	/// be necessary to manually set this value.
	///
	/// - Parameter value: The `Content-Type` value.
	///
	/// - Returns:         The header.
	static func contentType(_ value: ContentType) -> HTTPHeader {
		HTTPHeader(.contentType, value.rawValue)
	}

	/// Returns a `Sec-WebSocket-Protocol` header.
	///
	/// - Parameter value: The `Sec-WebSocket-Protocol` value.
	/// - Returns:         The header.
	static func websocketProtocol(_ value: String) -> HTTPHeader {
		HTTPHeader("Sec-WebSocket-Protocol", value)
	}
}

extension [HTTPHeader] {

	/// Case-insensitively finds the index of an `HTTPHeader` with the provided name, if it exists.
	func index(of name: HTTPHeader.Key) -> Int? {
		let lowercasedName = name.rawValue.lowercased()
		return firstIndex { $0.name.rawValue.lowercased() == lowercasedName }
	}
}

// MARK: - Defaults

public extension HTTPHeaders {

	/// The default set of `HTTPHeaders` used by Alamofire. Includes `Accept-Encoding`, `Accept-Language`, and
	/// `User-Agent`.
	static let `default`: HTTPHeaders = [.defaultAcceptEncoding,
	                                     .defaultAcceptLanguage,
	                                     .defaultUserAgent]
}

public extension HTTPHeader {

	/// Returns Alamofire's default `Accept-Encoding` header, appropriate for the encodings supported by particular OS
	/// versions.
	///
	/// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
	static let defaultAcceptEncoding: HTTPHeader = {
		let encodings: [String]
		if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
			encodings = ["br", "gzip", "deflate"]
		} else {
			encodings = ["gzip", "deflate"]
		}

		return HTTPHeader(.acceptEncoding, encodings.qualityEncoded())
	}()

	/// Returns Alamofire's default `Accept-Language` header, generated by querying `Locale` for the user's
	/// `preferredLanguages`.
	///
	/// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
	static let defaultAcceptLanguage = HTTPHeader(.acceptLanguage, Locale.preferredLanguages.prefix(6).qualityEncoded())

	/// Returns Alamofire's default `User-Agent` header.
	///
	/// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
	///
	/// Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 13.0.0) network-client`
	static let defaultUserAgent: HTTPHeader = {
		let info = Bundle.main.infoDictionary
		let executable = (info?["CFBundleExecutable"] as? String) ??
			(ProcessInfo.processInfo.arguments.first?.split(separator: "/").last.map(String.init)) ??
			"Unknown"
		let bundle = info?["CFBundleIdentifier"] as? String ?? "Unknown"
		let appVersion = info?["CFBundleShortVersionString"] as? String ?? "Unknown"
		let appBuild = info?["CFBundleVersion"] as? String ?? "Unknown"

		let osNameVersion: String = {
			let version = ProcessInfo.processInfo.operatingSystemVersion
			let versionString = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
			let osName: String = {
				#if os(iOS)
				#if targetEnvironment(macCatalyst)
				return "macOS(Catalyst)"
				#else
				return "iOS"
				#endif
				#elseif os(watchOS)
				return "watchOS"
				#elseif os(tvOS)
				return "tvOS"
				#elseif os(macOS)
				return "macOS"
				#elseif os(Linux)
				return "Linux"
				#elseif os(Windows)
				return "Windows"
				#elseif os(Android)
				return "Android"
				#else
				return "Unknown"
				#endif
			}()

			return "\(osName) \(versionString)"
		}()

		let userAgent = "\(executable)/\(appVersion) (\(bundle); build:\(appBuild); \(osNameVersion)) network-client"

		return HTTPHeader(.userAgent, userAgent)
	}()
}

extension Collection<String> {

	func qualityEncoded() -> String {
		enumerated().map { index, encoding in
			let quality = 1.0 - (Double(index) * 0.1)
			return "\(encoding);q=\(quality)"
		}.joined(separator: ", ")
	}
}

// MARK: - System Type Extensions

public extension URLRequest {

	/// Returns `allHTTPHeaderFields` as `HTTPHeaders`.
	var headers: HTTPHeaders {
		get { allHTTPHeaderFields.map(HTTPHeaders.init) ?? HTTPHeaders() }
		set { allHTTPHeaderFields = newValue.dictionary }
	}

	mutating func setHeader(_ header: HTTPHeader) {
		setValue(header.value, forHTTPHeaderField: header.name.rawValue)
	}

	func value(forHTTPHeaderKey key: HTTPHeader.Key) -> String? {
		value(forHTTPHeaderField: key.rawValue)
	}
}

public extension HTTPURLResponse {

	/// Returns `allHeaderFields` as `HTTPHeaders`.
	var headers: HTTPHeaders {
		(allHeaderFields as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders()
	}
}

public extension URLSessionConfiguration {

	/// Returns `httpAdditionalHeaders` as `HTTPHeaders`.
	var headers: HTTPHeaders {
		get { (httpAdditionalHeaders as? [String: String]).map(HTTPHeaders.init) ?? HTTPHeaders() }
		set { httpAdditionalHeaders = newValue.dictionary }
	}
}
