import Foundation

enum QueryValue {

	typealias Keyed = [([Key], String)]

	case single(String)
	case keyed([(String, QueryValue)])
	case unkeyed([QueryValue])
	case null

	static let start = "?"
	static let comma = ","
	static let separator = "&"
	static let setter = "="
	static let openKey: Character = "["
	static let closeKey: Character = "]"
	static let point: Character = "."

	static func separateKey(_ key: String) -> [String] {
		var result: [String] = []
		var str = ""
		for char in key {
			switch char {
			case QueryValue.openKey:
				if result.isEmpty, !str.isEmpty {
					result.append(str)
					str = ""
				}
			case QueryValue.closeKey:
				result.append(str)
				str = ""
			case QueryValue.point:
				result.append(str)
				str = ""
			default:
				str.append(char)
			}
		}
		if result.isEmpty, !str.isEmpty {
			result.append(str)
		}
		return result
	}

	var unkeyed: [QueryValue] {
		get {
			if case let .unkeyed(result) = self {
				return result
			}
			return []
		}
		set {
			self = .unkeyed(newValue)
		}
	}

	var keyed: [(String, QueryValue)] {
		get {
			if case let .keyed(result) = self {
				return result
			}
			return []
		}
		set {
			self = .keyed(newValue)
		}
	}

	var single: String {
		get {
			if case let .single(result) = self {
				return result
			}
			return ""
		}
		set {
			self = .single(newValue)
		}
	}

	struct Key {

		let value: String
		let isInt: Bool

		static func string(_ string: String) -> Self { Self(value: string, isInt: false) }
		static func int(_ string: String) -> Self { Self(value: string, isInt: true) }
	}
}
