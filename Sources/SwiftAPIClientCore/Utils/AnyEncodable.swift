import Foundation

struct AnyEncodable: Encodable {

	var value: Encodable

	init(_ value: Encodable) {
		self.value = value
	}

	func encode(to encoder: Encoder) throws {
		// Encoders special-case types like Date and Decimal only when handed the value itself.
		var container = encoder.singleValueContainer()
		try container.encode(value)
	}
}
