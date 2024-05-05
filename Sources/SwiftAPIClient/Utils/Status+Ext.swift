import Foundation
import HTTPTypes

extension HTTPResponse.Status.Kind {

	var isError: Bool {
		self == .clientError || self == .serverError || self == .invalid
	}
}
