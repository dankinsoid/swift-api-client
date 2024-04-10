@preconcurrency import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient.Configs {

	/// Underlying URLSession of the client.
	var urlSession: URLSession {
		let session = URLSession.apiClient
		SessionDelegateProxy.shared.configs = self
		return session
	}
}

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
public extension APIClient.Configs {

	/// The delegate for the URLSession of the client.
	var urlSessionDelegate: URLSessionDelegate? {
		get { self[\.urlSessionDelegate] ?? nil }
		set { self[\.urlSessionDelegate] = newValue }
	}
}

public extension APIClient {

	/// Sets the URLSession delegate for the client.
	func urlSession(delegate: URLSessionDelegate?) -> Self {
		configs(\.urlSessionDelegate, delegate)
	}
}
#endif

private extension URLSession {

	static var apiClient: URLSession = {
		var configs = URLSessionConfiguration.default
		configs.headers = .default
		return URLSession(
			configuration: configs,
			delegate: SessionDelegateProxy.shared,
			delegateQueue: nil
		)
	}()
}

private extension URLSessionConfiguration {

	/// Returns `httpAdditionalHeaders` as `HTTPFields`.
	var headers: HTTPFields {
		get {
			(httpAdditionalHeaders as? [String: String]).map {
				HTTPFields(
					$0.compactMap { key, value in HTTPField.Name(key).map { HTTPField(name: $0, value: value) } }
				)
			} ?? [:]
		}
		set {
			httpAdditionalHeaders = Dictionary(
				newValue.map { ($0.name.rawName, $0.value) }
			) { [$0, $1].joined(separator: ", ") }
		}
	}
}
