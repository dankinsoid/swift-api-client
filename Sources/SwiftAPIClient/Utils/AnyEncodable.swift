import Foundation

struct AnyEncodable: Encodable {

	var value: Encodable

	init(_ value: Encodable) {
		self.value = value
	}

	func encode(to encoder: Encoder) throws {
		try value.encode(to: encoder)
	}
}
