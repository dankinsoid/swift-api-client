@preconcurrency import Foundation

public extension APIClient.Configs {

	/// The error decoder used to decode errors from network responses.
	/// Gets the currently set `ErrorDecoder`, or `.none` if not set.
	/// Sets a new `ErrorDecoder`.
	var errorDecoder: ErrorDecoder {
		get { self[\.errorDecoder] ?? .none }
		set { self[\.errorDecoder] = newValue }
	}
}

public extension APIClient {

	/// Use this modifier when you want the client to throw an error that is decoded from the response.
	/// - Parameter decoder: The `ErrorDecoder` to be used for decoding errors.
	/// - Returns: An instance of `APIClient` configured with the specified error decoder.
	///
	/// Example usage:
	/// ```swift
	/// client.errorDecoder(.decodable(ErrorResponse.self))
	/// ```
	func errorDecoder(_ decoder: ErrorDecoder) -> APIClient {
		configs(\.errorDecoder, decoder)
	}
}
