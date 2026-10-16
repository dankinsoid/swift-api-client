import Foundation
import HTTPTypes

extension HTTPResponse.Status.Kind {

	var isError: Bool {
		self == .clientError || self == .serverError || self == .invalid
	}
}

extension HTTPRequest.Method {
	
	var isSafe: Bool {
		switch self {
		case .get, .head, .options, .trace:
			return true
		default:
			return false
		}
	}
}
