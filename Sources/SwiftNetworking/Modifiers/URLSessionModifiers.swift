import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NetworkClient.Configs {

	/// Underlying URLSession of the client.
	var urlSession: URLSession {
		let session = URLSession.networkClient
		SessionDelegateProxy.shared.configs = self
		return session
	}

	/// The delegate for the URLSession of the client.
	var urlSessionDelegate: URLSessionDelegate? {
		get { self[\.urlSessionDelegate] ?? nil }
		set { self[\.urlSessionDelegate] = newValue }
	}
}

public extension NetworkClient {

	/// Sets the URLSession delegate for the client.
	func urlSession(delegate: URLSessionDelegate?) -> Self {
		configs(\.urlSessionDelegate, delegate)
	}
}

private extension URLSession {

	static var networkClient: URLSession = {
		var configs = URLSessionConfiguration.default
		configs.headers = .default
		return URLSession(
			configuration: configs,
			delegate: SessionDelegateProxy.shared,
			delegateQueue: nil
		)
	}()
}
