@preconcurrency import Foundation

public typealias APIModel = Codable & Equatable

public typealias DateTime = Date
public typealias File = Data
public typealias ID = UUID

extension Encodable {

	func encode() -> String {
		(self as? String) ?? "\(self)"
	}
}
