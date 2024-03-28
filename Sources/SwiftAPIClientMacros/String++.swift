import Foundation

extension String {

	var firstLowercased: String {
		isEmpty ? "" : prefix(1).lowercased() + dropFirst()
	}

	var firstUppercased: String {
		isEmpty ? "" : prefix(1).uppercased() + dropFirst()
	}

	var isOptional: Bool {
		hasSuffix("?") || hasPrefix("Optional<") && hasSuffix(">")
	}
    
    func removeCharacters(in set: CharacterSet) -> String {
        components(separatedBy: set).joined()
    }
}
