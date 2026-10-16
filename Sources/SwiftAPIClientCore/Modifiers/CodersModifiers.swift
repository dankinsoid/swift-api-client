import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient {

	/// Sets a request body encoder.
	///
	/// - Parameter encoder: A request body encoder.
	///
	/// - Returns: A new network client with the request body encoder.
	func bodyEncoder(_ encoder: some ContentEncoder) -> APIClient {
		configs(\.bodyEncoder, encoder)
	}

	/// Sets a response body decoder.
	///
	/// - Parameter decoder: A response body decoder.
	///
	/// - Returns: A new network client with the response body decoder.
	func bodyDecoder(_ decoder: some DataDecoder) -> APIClient {
		configs(\.bodyDecoder, decoder)
	}

	/// Sets a request query encoder.
	///
	/// - Parameter encoder: A request query encoder.
	///
	/// - Returns: A new network client with the request query encoder.
	func queryEncoder(_ encoder: some QueryEncoder) -> APIClient {
		configs(\.queryEncoder, encoder)
	}

	/// Sets a request headers encoder.
	///
	/// - Parameter encoder: A request headers encoder.
	///
	/// - Returns: A new network client with the request headers encoder.
	func headersEncoder(_ encoder: some HeadersEncoder) -> APIClient {
		configs(\.headersEncoder, encoder)
	}
}

public extension APIClient.Configs {

	/// A request body encoder.
	var bodyEncoder: any ContentEncoder {
		get { self[\.bodyEncoder] ?? JSONEncoder() }
		set { self[\.bodyEncoder] = newValue }
	}

	/// A response body decoder.
	var bodyDecoder: any DataDecoder {
		get { self[\.bodyDecoder] ?? JSONDecoder() }
		set { self[\.bodyDecoder] = newValue }
	}

	/// A request query encoder.
	var queryEncoder: any QueryEncoder {
		get { self[\.queryEncoder] ?? URLQueryEncoder() }
		set { self[\.queryEncoder] = newValue }
	}

	/// A request headers encoder.
	var headersEncoder: any HeadersEncoder {
		get { self[\.headersEncoder] ?? HTTPHeadersEncoder() }
		set { self[\.headersEncoder] = newValue }
	}
}
