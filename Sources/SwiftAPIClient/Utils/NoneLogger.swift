import Foundation
import Logging

public extension Logger {

	/// A logger that discards all log messages.
	static var none: Logger {
		Logger(label: "none") { _ in
			NoneLogger()
		}
	}
}

private struct NoneLogger: LogHandler {

	var metadata: Logger.Metadata = [:]
	var logLevel: Logger.Level = .critical

	func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, file: String, function: String, line: UInt) {}

	subscript(metadataKey metadataKey: String) -> Logger.Metadata.Value? {
		get { nil }
		set {}
	}
}
