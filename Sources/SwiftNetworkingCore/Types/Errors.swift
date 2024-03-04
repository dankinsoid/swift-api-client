import Foundation

enum Errors: LocalizedError {

	case unknown
	case invalidStatusCode(Int)
	case notConnected
	case mockIsMissed(Any.Type)
	case unimplemented
	case responseTypeIsNotHTTP
	case duplicateHeader(HTTPHeader.Key)
	case invalidFileURL(URL)

	var errorDescription: String? {
		switch self {
		case .unknown:
			return "Unknown error"
		case let .invalidStatusCode(code):
			return "Invalid status code: \(code)"
		case .notConnected:
			return "Not connected to the internet"
		case let .mockIsMissed(type):
			return "Mock for \(type) is missed"
		case .unimplemented:
			return "Unimplemented"
		case .responseTypeIsNotHTTP:
			return "Response type is not HTTP"
		case let .duplicateHeader(key):
			return "Duplicate header \(key)"
		case let .invalidFileURL(url):
			return "Invalid file URL \(url)"
		}
	}
}
