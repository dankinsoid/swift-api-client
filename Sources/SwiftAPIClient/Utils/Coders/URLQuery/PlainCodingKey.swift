@preconcurrency import Foundation

struct PlainCodingKey: CodingKey {

	var stringValue: String
	var intValue: Int?

	init(stringValue: String) {
		self.stringValue = stringValue
	}

	init(_ stringValue: String) {
		self.stringValue = stringValue
	}

	init(intValue: Int) {
		self.intValue = intValue
		stringValue = "\(intValue)"
	}
}
