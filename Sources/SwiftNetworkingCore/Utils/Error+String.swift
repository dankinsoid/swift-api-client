import Foundation

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
		case let .typeMismatch(any, context):
			return "Expected \(any) at \(context.humanReadable)"
		case let .valueNotFound(any, context):
			return "Value of \(any) not found at \(context.humanReadable)"
		case let .keyNotFound(codingKey, context):
			return "Key \(context.humanReadable + codingKey.string) not found"
		case let .dataCorrupted(context):
			return "Data corrupted at \(context.humanReadable)"
		@unknown default:
			return localizedDescription
		}
	}
}

private extension DecodingError.Context {

	var humanReadable: String {
		codingPath.map(\.string).joined()
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
