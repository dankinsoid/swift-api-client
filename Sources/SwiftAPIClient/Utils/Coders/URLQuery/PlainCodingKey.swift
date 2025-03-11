import Foundation

public struct PlainCodingKey: CodingKey, CustomStringConvertible {

	public var stringValue: String
	public var intValue: Int?

	public init(stringValue: String) {
		self.init(stringValue: stringValue, intValue: nil)
	}

	public init(_ codingKey: CodingKey) {
		self.init(stringValue: codingKey.stringValue, intValue: codingKey.intValue)
	}

	public init(_ stringValue: String) {
		self.init(stringValue: stringValue)
	}

	public init(stringValue: String, intValue: Int?) {
		self.stringValue = stringValue
		self.intValue = intValue
	}

	public init(intValue: Int) {
		self.init(stringValue: "\(intValue)", intValue: intValue)
	}

	public var description: String {
		stringValue
	}
}
