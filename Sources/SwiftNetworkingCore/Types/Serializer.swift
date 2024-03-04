import Foundation

/// A generic struct for serializing network responses into specified types.
public struct Serializer<Response, T> {

	/// A closure that serializes a network response into a specified type.
	public var serialize: (_ response: Response, _ configs: NetworkClient.Configs) throws -> T

	/// Initializes a new `Serializer` with a custom serialization closure.
	/// - Parameter serialize: A closure that takes a response and network configurations, then returns a serialized object of type `T`.
	public init(_ serialize: @escaping (Response, NetworkClient.Configs) throws -> T) {
		self.serialize = { response, configs in
			do {
				return try serialize(response, configs)
			} catch {
				configs.logger.error("Response decoding failed with error: `\(error.humanReadable)`")
				throw error
			}
		}
	}
}

public extension Serializer where Response == T {

	static var identity: Self {
		Self { response, _ in response }
	}
}

public extension Serializer where Response == Data, T == Data {

	/// A static property to get a `Serializer` that directly returns the response `Data`.
	static var data: Self {
		Self { data, _ in data }
	}
}

public extension Serializer where Response == Data, T == Void {

	/// A static property to get a `Serializer` that discards the response data.
	static var void: Self {
		Self { _, _ in }
	}
}

public extension Serializer where Response == Data, T: Decodable {

	/// Creates a `Serializer` for a specific `Decodable` type.
	/// - Returns: A `Serializer` that decodes the response data into the specified `Decodable` type.
	static func decodable(_: T.Type) -> Self {
		Self { data, configs in
			try configs.bodyDecoder.decode(T.self, from: data)
		}
	}

	/// A static property to get a `Serializer` for the generic `Decodable` type.
	static var decodable: Self {
		.decodable(T.self)
	}
}
