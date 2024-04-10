@preconcurrency import Foundation

/// A generic struct for serializing content into data and associated content type.
public struct ContentSerializer<T> {

	/// A closure that serializes a value of type `T` into `Data`.
	public var serialize: (_ value: T, _ configs: APIClient.Configs) throws -> Data
	/// A closure that return a content type of serialized data.
	public var contentType: (_ configs: APIClient.Configs) -> ContentType

	/// Initializes a new `ContentSerializer` with a custom serialization closure.
	/// - Parameters:
	///  - serialize: A closure that takes a value and network configurations and returns serialized data.
	///  - contentType: A closure that return a content type of serialized data.
	public init(
		_ serialize: @escaping (T, APIClient.Configs) throws -> Data,
		contentType: @escaping (_ configs: APIClient.Configs) -> ContentType
	) {
		self.serialize = serialize
		self.contentType = contentType
	}
}

public extension ContentSerializer where T: Encodable {

	/// A static property to get a `ContentSerializer` for `Encodable` types.
	static var encodable: Self {
		.encodable(T.self)
	}

	/// Creates a `ContentSerializer` for a specific `Encodable` type.
	/// - Returns: A `ContentSerializer` that uses the body encoder from the network client configurations to serialize the value.
	static func encodable(_: T.Type) -> Self {
		ContentSerializer { value, configs in
			try configs.bodyEncoder.encode(value)
		} contentType: { configs in
			configs.bodyEncoder.contentType
		}
	}
}
