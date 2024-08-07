import Foundation

enum Errors: LocalizedError, CustomStringConvertible {

	case unknown
	case notConnected
	case mockIsMissed(Any.Type)
	case unimplemented
	case responseTypeIsNotHTTP
	case duplicateHeader(HTTPField.Name)
	case invalidFileURL(URL)
	case invalidUTF8Data
	case custom(String)

	var errorDescription: String? {
		description
	}

	var description: String {
		switch self {
		case .unknown:
			return "Unknown error"
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
		case .invalidUTF8Data:
			return "Invalid UTF-8 data"
		case let .custom(message):
			return message
		}
	}
}
