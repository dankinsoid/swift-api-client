import Foundation

public extension APIClient {

	/// Set the fileID and line for logging. When setted `#line` and `#fileID` parameters in the `call` methods are ignored.
	@available(*, deprecated, renamed: "codeLocation(fileID:line:function:)")
	func fileIDLine(fileID: String, line: UInt) -> APIClient {
		configs(\.fileIDLine, CodeLocation(fileID: fileID, line: line))
	}

	/// Set the fileID, line and function for logging. When setted `#line`, `#fileID` and `#function` parameters in the `call` methods are ignored.
	func codeLocation(fileID: String, line: UInt, function: String) -> APIClient {
		configs(\.codeLocation, CodeLocation(fileID: fileID, line: line, function: function))
	}
}

public extension APIClient.Configs {

	/// The fileID and line of the call site.
	@available(*, deprecated, renamed: "codeLocation")
	var fileIDLine: CodeLocation? {
		get { codeLocation }
		set { codeLocation = newValue }
	}

	/// The code location of the call site.
	var codeLocation: CodeLocation? {
		get { self[\.codeLocation] }
		set { self[\.codeLocation] = newValue }
	}
}

@available(*, deprecated, renamed: "CodeLocation")
public typealias FileIDLine = CodeLocation

public struct CodeLocation: Hashable {

	public var fileID: String
	public var line: UInt
	public var function: String

	public init(fileID: String = #fileID, line: UInt = #line, function: String = #function) {
		self.fileID = fileID
		self.line = line
		self.function = function
	}

	public var source: String {
			let utf8All = fileID.utf8
			if let slashIndex = utf8All.firstIndex(of: UInt8(ascii: "/")) {
					return String(fileID[..<slashIndex])
			} else {
					return "n/a"
			}
	}
}
