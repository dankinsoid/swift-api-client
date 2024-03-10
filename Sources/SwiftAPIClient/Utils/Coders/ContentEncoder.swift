import Foundation

/// A protocol defining an encoder that serializes data into a specific content type.
public protocol ContentEncoder {

	/// The `ContentType` associated with the serialized data.
	/// This property specifies the MIME type that the encoder outputs.
	var contentType: ContentType { get }
	func encode<T: Encodable>(_ value: T) throws -> Data
}
