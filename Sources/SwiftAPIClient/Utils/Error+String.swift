@preconcurrency import Foundation

extension Error {

	var humanReadable: String {
		if let decodingError = self as? DecodingError {
			return decodingError.humanReadable
		}
		if let encodingError = self as? EncodingError {
			return encodingError.humanReadable
		}
		return localizedDescription
	}
}

private extension DecodingError {

	var humanReadable: String {
		switch self {
		case let .typeMismatch(_, context):
			return context.humanReadable
		case let .valueNotFound(_, context):
			return context.humanReadable
		case let .keyNotFound(_, context):
			return context.humanReadable
		case let .dataCorrupted(context):
			return context.humanReadable
		@unknown default:
			return localizedDescription
		}
	}
}

private extension DecodingError.Context {

	var humanReadable: String {
		"\(debugDescription) Path: \\\(codingPath.humanReadable)"
	}
}

extension [CodingKey] {

	var humanReadable: String {
		isEmpty ? "root" : map(\.string).joined()
	}
}

private extension EncodingError {

	var humanReadable: String {
		switch self {
		case let .invalidValue(any, context):
			return "Invalid value \(any) at \(context.humanReadable)"
		@unknown default:
			return errorDescription ?? "\(self)"
		}
	}
}

private extension EncodingError.Context {

	var humanReadable: String {
		codingPath.map(\.string).joined()
	}
}

private extension CodingKey {

	var string: String {
		if let intValue {
			return "[\(intValue)]"
		}
		return "." + stringValue
	}
}
