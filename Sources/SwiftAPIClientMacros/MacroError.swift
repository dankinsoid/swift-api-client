@preconcurrency import Foundation

struct MacroError: LocalizedError, CustomStringConvertible {

	var errorDescription: String
	var localizedDescription: String { errorDescription }
	var description: String { errorDescription }

	init(_ errorDescription: String) {
		self.errorDescription = errorDescription
	}
}
