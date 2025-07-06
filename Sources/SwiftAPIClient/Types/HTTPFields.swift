import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension HTTPField {

	/// Returns an `Accept` header.
	///
	/// - Parameter value: The `Accept` value.
	///
	/// - Returns:         The header
	static func accept(_ value: ContentType) -> HTTPField {
		HTTPField(name: .accept, value: value.rawValue)
	}

	/// Returns a `Basic` `Authorization` header using the `username` and `password` provided.
	///
	/// - Parameters:
	///   - username: The username of the header.
	///   - password: The password of the header.
	///
	/// - Returns:    The header.
	static func authorization(username: String, password: String) -> HTTPField {
		let credential = Data("\(username):\(password)".utf8).base64EncodedString()

		return authorization("Basic \(credential)")
	}

	/// Returns a `Bearer` `Authorization` header using the `bearerToken` provided
	///
	/// - Parameter bearerToken: The bearer token.
	///
	/// - Returns:               The header.
	static func authorization(bearerToken: String) -> HTTPField {
		authorization("Bearer \(bearerToken)")
	}

	/// Returns an `Authorization` header.
	///
	/// swift-api-client provides built-in methods to produce `Authorization` headers. For a Basic `Authorization` header use
	/// `HTTPField.authorization(username:password:)`. For a Bearer `Authorization` header, use
	/// `HTTPField.authorization(bearerToken:)`.
	///
	/// - Parameter value: The `Authorization` value.
	///
	/// - Returns:         The header.
	static func authorization(_ value: String) -> HTTPField {
		HTTPField(name: .authorization, value: value)
	}

	/// Returns a `Content-Disposition` header.
	///
	/// - Parameter value: The `Content-Disposition` value.
	///
	/// - Returns:         The header.
	static func contentDisposition(_ type: String, name: String, filename: String? = nil) -> HTTPField {
		let nameEncoded = name.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? name
		var value = "form-data; name=\"\(nameEncoded)\""
		if let filename {
			let filenameEncoded = filename.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? filename
			value += "; filename=\"\(filenameEncoded)\""
		}
		return HTTPField(name: .contentDisposition, value: value)
	}

	/// Returns a `Basic` `Proxy-Authorization` header using the `username` and `password` provided.
	///
	/// - Parameters:
	///   - username: The username of the header.
	///   - password: The password of the header.
	///
	/// - Returns:    The header.
	static func proxyAuthorization(username: String, password: String) -> HTTPField {
		let credential = Data("\(username):\(password)".utf8).base64EncodedString()
		return HTTPField(name: .proxyAuthorization, value: "Basic \(credential)")
	}

	/// Returns a `Content-Encoding` header.
	///
	/// - Parameter value: The `Content-Encoding`.
	///
	/// - Returns:         The header.
	static func contentEncoding(_ value: String) -> HTTPField {
		HTTPField(name: .contentEncoding, value: value)
	}

	/// Returns a `Content-Type` header.
	///
	/// All swift-api-client `ParameterEncoding`s and `ParameterEncoder`s set the `Content-Type` of the request, so it may not
	/// be necessary to manually set this value.
	///
	/// - Parameter value: The `Content-Type` value.
	///
	/// - Returns:         The header.
	static func contentType(_ value: ContentType) -> HTTPField {
		HTTPField(name: .contentType, value: value.rawValue)
	}

	/// Returns a `Sec-WebSocket-Protocol` header.
	///
	/// - Parameter value: The `Sec-WebSocket-Protocol` value.
	/// - Returns:         The header.
	static func webSocketProtocol(_ value: String) -> HTTPField {
		HTTPField(name: .secWebSocketProtocol, value: value)
	}

	// MARK: - Caching Headers

	/// Returns a `Cache-Control` header.
	///
	/// - Parameter value: The `Cache-Control` value.
	/// - Returns:         The header.
	static func cacheControl(_ value: String) -> HTTPField {
		HTTPField(name: .cacheControl, value: value)
	}

	/// Returns an `ETag` header.
	///
	/// - Parameter value: The `ETag` value.
	/// - Returns:         The header.
	static func eTag(_ value: String) -> HTTPField {
		HTTPField(name: .eTag, value: value)
	}

	/// Returns an `If-None-Match` header.
	///
	/// - Parameter value: The `If-None-Match` value.
	/// - Returns:         The header.
	static func ifNoneMatch(_ value: String) -> HTTPField {
		HTTPField(name: .ifNoneMatch, value: value)
	}

	/// Returns an `If-Modified-Since` header.
	///
	/// - Parameter value: The `If-Modified-Since` value.
	/// - Returns:         The header.
	static func ifModifiedSince(_ value: String) -> HTTPField {
		HTTPField(name: .ifModifiedSince, value: value)
	}

	// MARK: - Content Headers

	/// Returns a `Content-Length` header.
	///
	/// - Parameter value: The `Content-Length` value.
	/// - Returns:         The header.
	static func contentLength(_ value: Int) -> HTTPField {
		HTTPField(name: .contentLength, value: String(value))
	}

	/// Returns a `Content-Range` header.
	///
	/// - Parameter value: The `Content-Range` value.
	/// - Returns:         The header.
	static func contentRange(_ value: String) -> HTTPField {
		HTTPField(name: .contentRange, value: value)
	}

	/// Returns an `Accept-Charset` header.
	///
	/// - Parameter value: The `Accept-Charset` value.
	/// - Returns:         The header.
	static func acceptCharset(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("Accept-Charset")!, value: value)
	}

	/// Returns an `Accept-Ranges` header.
	///
	/// - Parameter value: The `Accept-Ranges` value.
	/// - Returns:         The header.
	static func acceptRanges(_ value: String) -> HTTPField {
		HTTPField(name: .acceptRanges, value: value)
	}

	// MARK: - CORS Headers

	/// Returns an `Access-Control-Allow-Origin` header.
	///
	/// - Parameter value: The `Access-Control-Allow-Origin` value.
	/// - Returns:         The header.
	static func accessControlAllowOrigin(_ value: String) -> HTTPField {
		HTTPField(name: .accessControlAllowOrigin, value: value)
	}

	/// Returns an `Access-Control-Allow-Methods` header.
	///
	/// - Parameter value: The `Access-Control-Allow-Methods` value.
	/// - Returns:         The header.
	static func accessControlAllowMethods(_ value: String) -> HTTPField {
		HTTPField(name: .accessControlAllowMethods, value: value)
	}

	/// Returns an `Access-Control-Allow-Headers` header.
	///
	/// - Parameter value: The `Access-Control-Allow-Headers` value.
	/// - Returns:         The header.
	static func accessControlAllowHeaders(_ value: String) -> HTTPField {
		HTTPField(name: .accessControlAllowHeaders, value: value)
	}

	// MARK: - Common Request Headers

	/// Returns an `X-Request-ID` header.
	///
	/// - Parameter value: The `X-Request-ID` value.
	/// - Returns:         The header.
	static func xRequestID(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("X-Request-ID")!, value: value)
	}

	/// Returns an `X-Correlation-ID` header.
	///
	/// - Parameter value: The `X-Correlation-ID` value.
	/// - Returns:         The header.
	static func xCorrelationID(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("X-Correlation-ID")!, value: value)
	}

	/// Returns an `Origin` header.
	///
	/// - Parameter value: The `Origin` value.
	/// - Returns:         The header.
	static func origin(_ value: String) -> HTTPField {
		HTTPField(name: .origin, value: value)
	}

	/// Returns a `Referer` header.
	///
	/// - Parameter value: The `Referer` value.
	/// - Returns:         The header.
	static func referer(_ value: String) -> HTTPField {
		HTTPField(name: .referer, value: value)
	}

	/// Returns an `X-Forwarded-For` header.
	///
	/// - Parameter value: The `X-Forwarded-For` value.
	/// - Returns:         The header.
	static func xForwardedFor(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("X-Forwarded-For")!, value: value)
	}

	/// Returns an `X-Real-IP` header.
	///
	/// - Parameter value: The `X-Real-IP` value.
	/// - Returns:         The header.
	static func xRealIP(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("X-Real-IP")!, value: value)
	}

	/// Returns an `X-Requested-With` header.
	///
	/// - Parameter value: The `X-Requested-With` value.
	/// - Returns:         The header.
	static func xRequestedWith(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("X-Requested-With")!, value: value)
	}

	/// Returns an `X-API-Key` header.
	///
	/// - Parameter value: The `X-API-Key` value.
	/// - Returns:         The header.
	static func xAPIKey(_ value: String) -> HTTPField {
		HTTPField(name: HTTPField.Name("X-API-Key")!, value: value)
	}
}

// MARK: - Defaults

public extension HTTPFields {

	/// The default set of `HTTPFields` used by swift-api-client. Includes `Accept-Encoding`, `Accept-Language`, and
	/// `User-Agent`.
	static let `default` = HTTPFields([
		.defaultAcceptEncoding,
		.defaultAcceptLanguage,
		.defaultUserAgent,
	])
}

public extension HTTPField {

	/// Returns swift-api-client's default `Accept-Encoding` header, appropriate for the encodings supported by particular OS
	/// versions.
	///
	/// See the [Accept-Encoding HTTP header documentation](https://tools.ietf.org/html/rfc7230#section-4.2.3) .
	static let defaultAcceptEncoding: HTTPField = {
		let encodings: [String]
		if #available(iOS 11.0, macOS 10.13, tvOS 11.0, watchOS 4.0, *) {
			encodings = ["br", "gzip", "deflate"]
		} else {
			encodings = ["gzip", "deflate"]
		}

		return HTTPField(name: .acceptEncoding, value: encodings.qualityEncoded())
	}()

	/// Returns swift-api-client's default `Accept-Language` header, generated by querying `Locale` for the user's
	/// `preferredLanguages`.
	///
	/// See the [Accept-Language HTTP header documentation](https://tools.ietf.org/html/rfc7231#section-5.3.5).
	static let defaultAcceptLanguage = HTTPField(name: .acceptLanguage, value: Locale.preferredLanguages.prefix(6).qualityEncoded())

	/// Returns swift-api-client's default `User-Agent` header.
	///
	/// See the [User-Agent header documentation](https://tools.ietf.org/html/rfc7231#section-5.5.3).
	///
	/// Example: `iOS Example/1.0 (org.alamofire.iOS-Example; build:1; iOS 13.0.0) network-client`
	static let defaultUserAgent: HTTPField = {
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

		return HTTPField(name: .userAgent, value: userAgent)
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
