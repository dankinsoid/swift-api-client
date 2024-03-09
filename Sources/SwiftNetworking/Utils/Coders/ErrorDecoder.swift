import Foundation

/// A type that represents an error decoding from a response body.
public struct ErrorDecoder {

	public var decodeError: (Data, NetworkClient.Configs) -> Error?

	public init(decodeError: @escaping (Data, NetworkClient.Configs) -> Error?) {
		self.decodeError = decodeError
	}
}

public extension ErrorDecoder {

	/// None custom error decoding.
	static var none: Self {
		ErrorDecoder { _, _ in nil }
	}

	/// Decodes the decodable error from the response body using the given `DataDecoder`.
	///
	/// - Parameters:
	///   - type: The type of the decodable error.
	///   - dataDecoder: The `DataDecoder` to use for decoding. If `nil`, the `bodyDecoder` of the `NetworkClient.Configs` will be used.
	static func decodable<Failure: Decodable & Error>(
		_ type: Failure.Type,
		dataDecoder: (any DataDecoder)? = nil
	) -> Self {
		ErrorDecoder { data, configs in
			try? (dataDecoder ?? configs.bodyDecoder).decode(Failure.self, from: data)
		}
	}
}
