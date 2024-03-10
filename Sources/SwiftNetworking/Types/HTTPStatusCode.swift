import Foundation

public struct HTTPStatusCode: Hashable, RawRepresentable, CustomStringConvertible, ExpressibleByIntegerLiteral {

	public var rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public init(integerLiteral value: Int) {
		self.init(value)
	}

	public init(_ rawValue: Int) {
		self.init(rawValue: rawValue)
	}

	public static let `continue` = HTTPStatusCode(100)
	public static let switchingProtocols = HTTPStatusCode(101)
	public static let processing = HTTPStatusCode(102)

	public static let ok = HTTPStatusCode(200)
	public static let created = HTTPStatusCode(201)
	public static let accepted = HTTPStatusCode(202)
	public static let nonAuthoritativeInformation = HTTPStatusCode(203)
	public static let noContent = HTTPStatusCode(204)
	public static let resetContent = HTTPStatusCode(205)
	public static let partialContent = HTTPStatusCode(206)
	public static let multiStatus = HTTPStatusCode(207)
	public static let alreadyReported = HTTPStatusCode(208)
	public static let imUsed = HTTPStatusCode(226)

	public static let multipleChoices = HTTPStatusCode(300)
	public static let movedPermanently = HTTPStatusCode(301)
	public static let found = HTTPStatusCode(302)
	public static let seeOther = HTTPStatusCode(303)
	public static let notModified = HTTPStatusCode(304)
	public static let useProxy = HTTPStatusCode(305)
	public static let temporaryRedirect = HTTPStatusCode(307)
	public static let permanentRedirect = HTTPStatusCode(308)

	public static let badRequest = HTTPStatusCode(400)
	public static let unauthorized = HTTPStatusCode(401)
	public static let paymentRequired = HTTPStatusCode(402)
	public static let forbidden = HTTPStatusCode(403)
	public static let notFound = HTTPStatusCode(404)
	public static let methodNotAllowed = HTTPStatusCode(405)
	public static let notAcceptable = HTTPStatusCode(406)
	public static let proxyAuthenticationRequired = HTTPStatusCode(407)
	public static let requestTimeout = HTTPStatusCode(408)
	public static let conflict = HTTPStatusCode(409)
	public static let gone = HTTPStatusCode(410)
	public static let lengthRequired = HTTPStatusCode(411)
	public static let preconditionFailed = HTTPStatusCode(412)
	public static let payloadTooLarge = HTTPStatusCode(413)
	public static let uriTooLong = HTTPStatusCode(414)
	public static let unsupportedMediaType = HTTPStatusCode(415)
	public static let rangeNotSatisfiable = HTTPStatusCode(416)
	public static let expectationFailed = HTTPStatusCode(417)
	public static let imATeapot = HTTPStatusCode(418)
	public static let misdirectedRequest = HTTPStatusCode(421)
	public static let unprocessableEntity = HTTPStatusCode(422)
	public static let locked = HTTPStatusCode(423)
	public static let failedDependency = HTTPStatusCode(424)
	public static let upgradeRequired = HTTPStatusCode(426)
	public static let preconditionRequired = HTTPStatusCode(428)
	public static let tooManyRequests = HTTPStatusCode(429)
	public static let requestHeaderFieldsTooLarge = HTTPStatusCode(431)
	public static let unavailableForLegalReasons = HTTPStatusCode(451)

	public static let internalServerError = HTTPStatusCode(500)
	public static let notImplemented = HTTPStatusCode(501)
	public static let badGateway = HTTPStatusCode(502)
	public static let serviceUnavailable = HTTPStatusCode(503)
	public static let gatewayTimeout = HTTPStatusCode(504)
	public static let httpVersionNotSupported = HTTPStatusCode(505)
	public static let variantAlsoNegotiates = HTTPStatusCode(506)
	public static let insufficientStorage = HTTPStatusCode(507)
	public static let loopDetected = HTTPStatusCode(508)
	public static let notExtended = HTTPStatusCode(510)
	public static let networkAuthenticationRequired = HTTPStatusCode(511)

	public var isSuccess: Bool {
		(200 ..< 300).contains(rawValue)
	}

	public var name: String {
		switch self {
		case .continue: return "CONTINUE"
		case .switchingProtocols: return "SWITCHING PROTOCOLS"
		case .processing: return "PROCESSING"

		case .ok: return "OK"
		case .created: return "CREATED"
		case .accepted: return "ACCEPTED"
		case .nonAuthoritativeInformation: return "NON AUTHORITATIVE INFORMATION"
		case .noContent: return "NO CONTENT"
		case .resetContent: return "RESET CONTENT"
		case .partialContent: return "PARTIAL CONTENT"
		case .multiStatus: return "MULTI STATUS"
		case .alreadyReported: return "ALREADY REPORTED"
		case .imUsed: return "IM USED"

		case .multipleChoices: return "MULTIPLE CHOICES"
		case .movedPermanently: return "MOVED PERMANENTLY"
		case .found: return "FOUND"
		case .seeOther: return "SEE OTHER"
		case .notModified: return "NOT MODIFIED"
		case .useProxy: return "USE PROXY"
		case .temporaryRedirect: return "TEMPORARY REDIRECT"
		case .permanentRedirect: return "PERMANENT REDIRECT"

		case .badRequest: return "BAD REQUEST"
		case .unauthorized: return "UNAUTHORIZED"
		case .paymentRequired: return "PAYMENT REQUIRED"
		case .forbidden: return "FORBIDDEN"
		case .notFound: return "NOT FOUND"
		case .methodNotAllowed: return "METHOD NOT ALLOWED"
		case .notAcceptable: return "NOT ACCEPTABLE"
		case .proxyAuthenticationRequired: return "PROXY AUTHENTICATION REQUIRED"
		case .requestTimeout: return "REQUEST TIMEOUT"
		case .conflict: return "CONFLICT"
		case .gone: return "GONE"
		case .lengthRequired: return "LENGTH REQUIRED"
		case .preconditionFailed: return "PRECONDITION FAILED"
		case .payloadTooLarge: return "PAYLOAD TOO LARGE"
		case .uriTooLong: return "URI TOO LONG"
		case .unsupportedMediaType: return "UNSUPPORTED MEDIA TYPE"
		case .rangeNotSatisfiable: return "RANGE NOT SATISFIABLE"
		case .expectationFailed: return "EXPECTATION FAILED"
		case .imATeapot: return "IM A TEAPOT"
		case .misdirectedRequest: return "MISDIRECTED REQUEST"
		case .unprocessableEntity: return "UNPROCESSABLE ENTITY"
		case .locked: return "LOCKED"
		case .failedDependency: return "FAILED DEPENDENCY"
		case .upgradeRequired: return "UPGRADE REQUIRED"
		case .preconditionRequired: return "PRECONDITION REQUIRED"
		case .tooManyRequests: return "TOO MANY REQUESTS"
		case .requestHeaderFieldsTooLarge: return "REQUEST HEADER FIELDS TOO LARGE"
		case .unavailableForLegalReasons: return "UNAVAILABLE FOR LEGAL REASONS"

		case .internalServerError: return "INTERNAL SERVER ERROR"
		case .notImplemented: return "NOT IMPLEMENTED"
		case .badGateway: return "BAD GATEWAY"
		case .serviceUnavailable: return "SERVICE UNAVAILABLE"
		case .gatewayTimeout: return "GATEWAY TIMEOUT"
		case .httpVersionNotSupported: return "HTTP VERSION NOT SUPPORTED"
		case .variantAlsoNegotiates: return "VARIANT ALSO NEGOTIATES"
		case .insufficientStorage: return "INSUFFICIENT STORAGE"
		case .loopDetected: return "LOOP DETECTED"
		case .notExtended: return "NOT EXTENDED"
		case .networkAuthenticationRequired: return "NETWORK AUTHENTICATION REQUIRED"

		default: return isSuccess ? "SUCCESS" : "ERROR"
		}
	}

	public var description: String {
		rawValue.description
	}
}

public extension HTTPURLResponse {

	/// Returns `statusCode` as `HTTPStatusCode`.
	var httpStatusCode: HTTPStatusCode {
		HTTPStatusCode(statusCode)
	}
}
