import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension NetworkClient {

	/// Adds a closure to be executed when an HTTP response is received.
	///
	/// - Parameters:
	///   - action: The closure to be executed, which takes the HTTPURLResponse, Data, and NetworkClient.Configs as parameters.
	/// - Returns: The modified NetworkClient instance.
	func onHTTPResponse(_ action: @escaping (HTTPURLResponse, Data, NetworkClient.Configs) -> Void) -> NetworkClient {
		configs {
			let client = $0.httpClient
			$0.httpClient = HTTPClient { req, configs in
				let (data, response) = try await client.data(req, configs)
				action(response, data, configs)
				return (data, response)
			}
		}
	}

	/// Maps the HTTP response using the provided action.
	/// - Parameters:
	///   - action: A closure that takes an HTTPURLResponse, Data, and NetworkClient.Configs as input and returns a tuple of Data and HTTPURLResponse.
	/// - Returns: A modified NetworkClient instance.
	func mapHTTPResponse(_ action: @escaping (HTTPURLResponse, Data, NetworkClient.Configs) async throws -> (Data, HTTPURLResponse)) -> NetworkClient {
		configs {
			let client = $0.httpClient
			$0.httpClient = HTTPClient { req, configs in
				let (data, response) = try await client.data(req, configs)
				return try await action(response, data, configs)
			}
		}
	}
}
