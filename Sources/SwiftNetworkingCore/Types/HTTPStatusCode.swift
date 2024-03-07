import Foundation

public struct HTTPStatusCode: Hashable, RawRepresentable, CustomStringConvertible {

	public var rawValue: Int

	public init(rawValue: Int) {
		self.rawValue = rawValue
	}

	public init(_ rawValue: Int) {
		self.init(rawValue: rawValue)
	}

	static let `continue` = HTTPStatusCode(100)
	static let switchingProtocols = HTTPStatusCode(101)
	static let processing = HTTPStatusCode(102)

	static let ok = HTTPStatusCode(200)
	static let created = HTTPStatusCode(201)
	static let accepted = HTTPStatusCode(202)
	static let nonAuthoritativeInformation = HTTPStatusCode(203)
	static let noContent = HTTPStatusCode(204)
	static let resetContent = HTTPStatusCode(205)
	static let partialContent = HTTPStatusCode(206)
	static let multiStatus = HTTPStatusCode(207)
	static let alreadyReported = HTTPStatusCode(208)
	static let imUsed = HTTPStatusCode(226)

	static let multipleChoices = HTTPStatusCode(300)
	static let movedPermanently = HTTPStatusCode(301)
	static let found = HTTPStatusCode(302)
	static let seeOther = HTTPStatusCode(303)
	static let notModified = HTTPStatusCode(304)
	static let useProxy = HTTPStatusCode(305)
	static let temporaryRedirect = HTTPStatusCode(307)
	static let permanentRedirect = HTTPStatusCode(308)

	static let badRequest = HTTPStatusCode(400)
	static let unauthorized = HTTPStatusCode(401)
	static let paymentRequired = HTTPStatusCode(402)
	static let forbidden = HTTPStatusCode(403)
	static let notFound = HTTPStatusCode(404)
	static let methodNotAllowed = HTTPStatusCode(405)
	static let notAcceptable = HTTPStatusCode(406)
	static let proxyAuthenticationRequired = HTTPStatusCode(407)
	static let requestTimeout = HTTPStatusCode(408)
	static let conflict = HTTPStatusCode(409)
	static let gone = HTTPStatusCode(410)
	static let lengthRequired = HTTPStatusCode(411)
	static let preconditionFailed = HTTPStatusCode(412)
	static let payloadTooLarge = HTTPStatusCode(413)
	static let uriTooLong = HTTPStatusCode(414)
	static let unsupportedMediaType = HTTPStatusCode(415)
	static let rangeNotSatisfiable = HTTPStatusCode(416)
	static let expectationFailed = HTTPStatusCode(417)
	static let imATeapot = HTTPStatusCode(418)
	static let misdirectedRequest = HTTPStatusCode(421)
	static let unprocessableEntity = HTTPStatusCode(422)
	static let locked = HTTPStatusCode(423)
	static let failedDependency = HTTPStatusCode(424)
	static let upgradeRequired = HTTPStatusCode(426)
	static let preconditionRequired = HTTPStatusCode(428)
	static let tooManyRequests = HTTPStatusCode(429)
	static let requestHeaderFieldsTooLarge = HTTPStatusCode(431)
	static let unavailableForLegalReasons = HTTPStatusCode(451)

	static let internalServerError = HTTPStatusCode(500)
	static let notImplemented = HTTPStatusCode(501)
	static let badGateway = HTTPStatusCode(502)
	static let serviceUnavailable = HTTPStatusCode(503)
	static let gatewayTimeout = HTTPStatusCode(504)
	static let httpVersionNotSupported = HTTPStatusCode(505)
	static let variantAlsoNegotiates = HTTPStatusCode(506)
	static let insufficientStorage = HTTPStatusCode(507)
	static let loopDetected = HTTPStatusCode(508)
	static let notExtended = HTTPStatusCode(510)
	static let networkAuthenticationRequired = HTTPStatusCode(511)

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
