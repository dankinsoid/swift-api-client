@preconcurrency import Foundation

public extension APIClient {

	/// Set the fileID and line for logging. When setted `#line` and `#fileID` parameters in the `call` methods are ignored.
	func fileIDLine(fileID: String, line: UInt) -> APIClient {
		configs(\.fileIDLine, FileIDLine(fileID: fileID, line: line))
	}
}

public extension APIClient.Configs {

	/// The fileID and line of the call site.
	var fileIDLine: FileIDLine? {
		get { self[\.fileIDLine] }
		set { self[\.fileIDLine] = newValue }
	}
}

public struct FileIDLine: Hashable {

	public let fileID: String
	public let line: UInt

	public init(fileID: String = #fileID, line: UInt = #line) {
		self.fileID = fileID
		self.line = line
	}
}
