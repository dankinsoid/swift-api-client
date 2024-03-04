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
		self.serialize = { value, configs in
			do {
				return try serialize(value, configs)
			} catch {
				configs.logger.error("Response decoding failed with error: `\(error.humanReadable)`")
				throw error
			}
		}
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

//public extension ContentSerializer where T == JSON {
//
//	/// A static property to get a `ContentSerializer` for JSON.
//	static var json: Self {
//		Self { json, _ in (json.data, .application(.json)) }
//	}
//}
//
//public extension ContentSerializer where T: Collection, T.Element == MultipartFormData.PartParam {
//
//	/// A static property to get a `ContentSerializer` for multipart/form-data with a default boundary.
//	static var multipartFormData: Self {
//		.multipartFormData(boundary: defaultBoundary)
//	}
//
//	/// Creates a `ContentSerializer` for multipart/form-data with a custom boundary.
//	/// - Parameter boundary: The boundary string to use in the multipart/form-data.
//	/// - Returns: A `ContentSerializer` that constructs multipart/form-data using the provided boundary.
//	static func multipartFormData(boundary: String) -> Self {
//		Self { partParams, _ in
//			try (
//				MultipartFormData.Builder.build(
//					with: Array(partParams),
//					willSeparateBy: boundary
//				).body,
//				.multipart(.formData)
//			)
//		}
//	}
//}
