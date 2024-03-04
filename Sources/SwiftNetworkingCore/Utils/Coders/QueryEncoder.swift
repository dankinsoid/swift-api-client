import Foundation

/// Protocol defining an encoder that serializes data into a query parameters array.
public protocol QueryEncoder {

	func encode<T: Encodable>(_ value: T) throws -> [URLQueryItem]
}
