import Foundation

enum ParametersValue: Encodable {

	typealias Keyed = [([CodingKey], String)]

	case single(String, Encodable)
	case keyed([(String, ParametersValue)])
	case unkeyed([ParametersValue])
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
			case ParametersValue.openKey:
				if result.isEmpty, !str.isEmpty {
					result.append(str)
					str = ""
				}
			case ParametersValue.closeKey:
				result.append(str)
				str = ""
			case ParametersValue.point:
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

	var unkeyed: [ParametersValue] {
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

	var keyed: [(String, ParametersValue)] {
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

	func encode(to encoder: any Encoder) throws {
		switch self {
		case let .single(_, value):
			try value.encode(to: encoder)
		case let .keyed(values):
			var container = encoder.container(keyedBy: PlainCodingKey.self)
			for (key, value) in values {
				try container.encode(value, forKey: PlainCodingKey(key))
			}
		case let .unkeyed(values):
			var container = encoder.unkeyedContainer()
			for value in values {
				try container.encode(value)
			}
		case .null:
			var container = encoder.singleValueContainer()
			try container.encodeNil()
		}
	}
}
