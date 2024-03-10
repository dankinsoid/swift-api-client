import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension NetworkClient.Configs {

	/// Underlying URLSession of the client.
	var urlSession: URLSession {
		let session = URLSession.networkClient
		#if !canImport(FoundationNetworking)
		SessionDelegateProxy.shared.configs = self
		#endif
		return session
	}

	#if !canImport(FoundationNetworking)
	/// The delegate for the URLSession of the client.
	var urlSessionDelegate: URLSessionDelegate? {
		get { self[\.urlSessionDelegate] ?? nil }
		set { self[\.urlSessionDelegate] = newValue }
	}
	#endif
}

#if !canImport(FoundationNetworking)
public extension NetworkClient {

	/// Sets the URLSession delegate for the client.
	func urlSession(delegate: URLSessionDelegate?) -> Self {
		configs(\.urlSessionDelegate, delegate)
	}
}
#endif

private extension URLSession {

	static var networkClient: URLSession = {
		#if !canImport(FoundationNetworking)
		var configs = URLSessionConfiguration.default
		configs.headers = .default
		return URLSession(
			configuration: configs,
			delegate: SessionDelegateProxy.shared,
			delegateQueue: nil
		)
		#else
		return URLSession.shared
		#endif
	}()
}
