import Foundation

struct FullPath: Equatable, CustomStringConvertible {

	private(set) var path: [String]
	var queryItems: [URLQueryItem]
	var fragment: String?

	var description: String {
		var result = path.joined(separator: "/")
		if !queryItems.isEmpty {
			result += "?" + queryItems.map {
				"\($0.name)=\($0.value ?? "")"
			}
			.joined(separator: "&")
		}
		if let fragment {
			result += "#\(fragment)"
		}
		return result
	}

	init(path: [String], queryItems: [URLQueryItem] = [], fragment: String? = nil) {
		self.path = path
		self.queryItems = queryItems
		self.fragment = fragment
	}

	init(_ fullPath: String) {
		path = []
		queryItems = []
		fragment = nil

		var last: Character?
		var current = ""
		var currentQueryName = ""
		var parsingMode: ParsingMode = .path

		for char in fullPath {
			switch parsingMode {
			case .path:
				if char == "?" {
					if !current.isEmpty || last == "/" { path.append(current) }
					current = ""
					currentQueryName = ""
					parsingMode = .queryName
				} else if char == "#" {
					if !current.isEmpty || last == "/" { path.append(current) }
					current = ""
					parsingMode = .fragment
				} else if char == "/" {
					path.append(current)
					current = ""
				} else {
					current.append(char)
				}
			case .queryName:
				if char == "=" {
					current = ""
					parsingMode = .queryValue
				} else if char == "#" {
					if !currentQueryName.isEmpty {
						queryItems.append(URLQueryItem(name: currentQueryName, value: nil))
					}
					current = ""
					parsingMode = .fragment
				} else if char == "&" {
					if !currentQueryName.isEmpty {
						queryItems.append(
							URLQueryItem(name: currentQueryName, value: current)
						)
					}
					current = ""
					currentQueryName = ""
					parsingMode = .queryName
				} else {
					currentQueryName.append(char)
				}
			case .queryValue:
				if char == "&" {
					queryItems.append(URLQueryItem(name: currentQueryName, value: current))
					current = ""
					currentQueryName = ""
					parsingMode = .queryName
				} else if char == "#" {
					queryItems.append(URLQueryItem(name: currentQueryName, value: current))
					current = ""
					parsingMode = .fragment
				} else {
					current.append(char)
				}
			case .fragment:
				current.append(char)
			}
			last = char
		}
		switch parsingMode {
		case .path:
			path.append(current)
		case .queryName:
			if !currentQueryName.isEmpty {
				queryItems.append(URLQueryItem(name: currentQueryName, value: nil))
			}
		case .queryValue:
			queryItems.append(URLQueryItem(name: currentQueryName, value: current))
		case .fragment:
			fragment = current
		}
	}

	mutating func append(path: [String]) {
		if self.path.last == "" {
			self.path.removeLast()
			self.path += path
			self.path.append("")
		} else {
			self.path += path
		}
	}
}

private enum ParsingMode {

	case path, queryName, queryValue, fragment
}
