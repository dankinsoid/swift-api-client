import Foundation

/// A generic struct for serializing content into data and associated content type.
public struct ContentSerializer<T> {

	/// A closure that serializes a value of type `T` into `Data` and a corresponding `ContentType`.
	public var serialize: (_ value: T, _ configs: NetworkClient.Configs) throws -> (Data, ContentType)

	/// Initializes a new `ContentSerializer` with a custom serialization closure.
	/// - Parameter serialize: A closure that takes a value and network configurations and returns serialized data and its content type.
	public init(
		_ serialize: @escaping (T, NetworkClient.Configs) throws -> (Data, ContentType)
	) {
		self.serialize = serialize
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
			let encoder = configs.bodyEncoder
			return try (encoder.encode(value), encoder.contentType)
		}
	}
}
