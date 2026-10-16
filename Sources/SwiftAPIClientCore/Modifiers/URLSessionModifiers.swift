import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient.Configs {

	/// Underlying URLSession of the client.
	var urlSession: URLSession {
		let session = urlSessionConfiguration.map(URLSessionCache.shared.session) ?? URLSession.apiClient
		SessionDelegateProxy.shared.configs = self
		return session
	}
}

public extension APIClient.Configs {

	/// The delegate for the URLSession of the client.
	var urlSessionDelegate: URLSessionDelegate? {
		get { self[\.urlSessionDelegate] ?? nil }
		set { self[\.urlSessionDelegate] = newValue }
	}

	/// The configuration of the client's URLSession; `nil` means `.default`. One session per configuration instance.
	var urlSessionConfiguration: URLSessionConfiguration? {
		get { self[\.urlSessionConfiguration] ?? nil }
		set { self[\.urlSessionConfiguration] = newValue }
	}
}

public extension APIClient {

	/// Sets the URLSession delegate for the client.
	func urlSession(delegate: URLSessionDelegate?) -> Self {
		configs(\.urlSessionDelegate, delegate)
	}

	/// Sets the configuration of the client's URLSession, e.g. `.ephemeral` or one with a custom `urlCache`.
	///
	/// Each configuration instance gets its own session, so set it on a long-lived client, not per request.
	/// The session copies the configuration on the first request; later changes to the instance are ignored.
	func urlSession(configuration: URLSessionConfiguration) -> Self {
		configs(\.urlSessionConfiguration, configuration)
	}
}

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

// @unchecked: all state is guarded by `lock`.
private final class URLSessionCache: @unchecked Sendable {

	static let shared = URLSessionCache()

	private struct Entry {
		// Weak: the session lives as long as clients reference its configuration.
		weak var configuration: URLSessionConfiguration?
		let session: URLSession
	}

	private let lock = NSLock()
	private var entries: [ObjectIdentifier: Entry] = [:]

	func session(for configuration: URLSessionConfiguration) -> URLSession {
		lock.lock()
		defer { lock.unlock() }
		let key = ObjectIdentifier(configuration)
		// The identity check guards against a deallocated configuration's address being reused.
		if let entry = entries[key], entry.configuration === configuration {
			return entry.session
		}
		purgeReleased()
		let sessionConfiguration = configuration.copy() as! URLSessionConfiguration
		var headers = HTTPFields.default
		for field in sessionConfiguration.headers {
			headers[fields: field.name] = [field]
		}
		sessionConfiguration.headers = headers
		let session = URLSession(
			configuration: sessionConfiguration,
			delegate: SessionDelegateProxy.shared,
			delegateQueue: nil
		)
		entries[key] = Entry(configuration: configuration, session: session)
		return session
	}

	private func purgeReleased() {
		for (key, entry) in entries where entry.configuration == nil {
			entry.session.finishTasksAndInvalidate()
			entries[key] = nil
		}
	}
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
