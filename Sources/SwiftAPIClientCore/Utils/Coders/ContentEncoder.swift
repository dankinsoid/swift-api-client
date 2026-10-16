import Foundation

/// A protocol defining an encoder that serializes data.
public protocol DataEncoder {

	func encode<T: Encodable>(_ value: T) throws -> Data
}

/// A protocol defining an encoder that serializes data into a specific content type.
public protocol ContentEncoder: DataEncoder {

	/// The `ContentType` associated with the serialized data.
	/// This property specifies the MIME type that the encoder outputs.
	var contentType: ContentType { get }
}
