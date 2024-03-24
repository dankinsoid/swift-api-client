import Foundation

extension HTTPRequest {

	var _authority: Authority? {
		get { authority.map { Authority($0) } }
		set { authority = newValue?.description }
	}
}

struct Authority: Equatable, CustomStringConvertible {

	var userinfo: String?
	var host: String
	var port: Int?

	var description: String {
		var result = ""
		if let userinfo {
			result += userinfo + "@"
		}
		result += host
		if let port {
			result += ":\(port)"
		}
		return result
	}

	init(userinfo: String? = nil, host: String, port: Int? = nil) {
		self.userinfo = userinfo
		self.host = host
		self.port = port
	}

	init(_ authority: String) {
		var hostStart: String.Index = authority.startIndex
		var hostEnd: String.Index = authority.endIndex
		for i in authority.indices {
			if authority[i] == "@" {
				userinfo = String(authority[authority.startIndex ..< i])
				hostStart = authority.index(after: i)
			}
			if authority[i] == ":", let port = Int(authority[authority.index(after: i)...]) {
				hostEnd = i
				self.port = port
				break
			}
		}
		guard hostEnd > hostStart else {
			host = ""
			return
		}
		host = String(authority[hostStart ..< hostEnd])
	}
}
