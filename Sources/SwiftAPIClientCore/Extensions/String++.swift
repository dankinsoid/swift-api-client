import Foundation

extension String {

	/// Returns all matches for a regular expression pattern
	func matches(for pattern: String) -> [[String?]] {
		guard let regex = try? NSRegularExpression(pattern: pattern) else {
			return []
		}

		let range = NSRange(location: 0, length: utf16.count)
		let matches = regex.matches(in: self, range: range)

		return matches.map { match in
			(0 ..< match.numberOfRanges).map { rangeIndex in
				let range = match.range(at: rangeIndex)
				guard range.location != NSNotFound else { return nil }
				return (self as NSString).substring(with: range)
			}
		}
	}

	/// Returns the first match for a regular expression pattern
	func firstMatch(for pattern: String) -> [String?]? {
		matches(for: pattern).first
	}

	/// Converts a string to a different case
	/// - Parameter transform: The transformation to apply to the string words
	/// - Returns: The transformed string
	/// Examples:
	/// ```swift
	/// "hello world".convertToCase { $0.map { $0.uppercased() }.joined(separator: " ") } // "HELLO WORLD"
	/// "hello world".convertToCase { $0.map(\.capitalized).joined(separator: " ") } // "Hello World"
	/// "helloWorld".convertToCase { $0.map { $0.lowercased() }.joined(separator: " ") } // "hello world"
	/// "hello-world".convertToCase { $0.map(\.capitalized).joined(separator: " ") } // "Hello World"
	/// "hello_world".convertToCase { $0.map(\.capitalized).joined(separator: " ") } // "Hello World"
	/// "helloWorld".convertToCase { $0.map(\.capitalized).joined(separator: "-") } // "Hello-World"
	/// ```
	func convertToCase(_ transform: ([String]) -> String) -> String {
		guard !isEmpty else { return transform([]) }
		var words = [String]()
		var currentWord = ""
		var lastCharacter: Character?
		for character in self {
			if character.isUppercase && lastCharacter?.isLowercase == true || !character.isWord && lastCharacter?.isWord == true {
				words.append(currentWord)
				if character.isWord {
					currentWord = String(character)
				}
			} else {
				if character.isWord || words.isEmpty {
					currentWord.append(character)
				}
			}
			lastCharacter = character
		}
		words.append(currentWord)
		return transform(words)
	}

	func convertToSnakeCase() -> String {
		var result = ""
		for (i, char) in enumerated() {
			if char.isUppercase {
				if i != 0 {
					result.append("_")
				}
				result.append(char.lowercased())
			} else {
				result.append(char)
			}
		}
		return result
	}

	var lowercasedFirstLetter: String {
		prefix(1).lowercased() + dropFirst()
	}
}

private extension Character {

	var isWord: Bool {
		isLetter || isNumber
	}
}
