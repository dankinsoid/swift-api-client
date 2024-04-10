@preconcurrency import Foundation
import Logging

struct ConsoleStyle {

	var prefix: String

	static let error = ConsoleStyle(prefix: "\u{001B}[91m")
	static let success = ConsoleStyle(prefix: "\u{001B}[32m")
}

extension String {

	func consoleStyle(_ style: ConsoleStyle) -> String {
		"\(style.prefix)\(self)\u{001B}[0m"
	}
}

extension Logger.Level {

	/// Converts log level to console style
	var style: ConsoleStyle {
		switch self {
		case .trace: return ConsoleStyle(prefix: "\u{001B}[96m")
		case .debug: return ConsoleStyle(prefix: "\u{001B}[94m")
		case .info, .notice: return .success
		case .warning: return ConsoleStyle(prefix: "\u{001B}[33m")
		case .error: return .error
		case .critical: return ConsoleStyle(prefix: "\u{001B}[95m")
		}
	}
}
