import Foundation

public protocol APIClientListener {
	
	func onRequestStarted(id: UUID, request: HTTPRequestComponents, configs: APIClient.Configs)
	func onResponseReceived<R>(id: UUID, response: R, configs: APIClient.Configs)
	func onResponseSerialized<T>(id: UUID, response: T, configs: APIClient.Configs)
	func onRequestFailed(id: UUID, error: Error, configs: APIClient.Configs)
	func onRequestCompleted(id: UUID, configs: APIClient.Configs)
}

public extension APIClientListener {
	
	func onRequestStarted(id: UUID, request: HTTPRequestComponents, configs: APIClient.Configs) {}
	func onResponseReceived<R>(id: UUID, response: R, configs: APIClient.Configs) {}
	func onResponseSerialized<T>(id: UUID, response: T, configs: APIClient.Configs) {}
	func onRequestFailed(id: UUID, error: Error, configs: APIClient.Configs) {}
	func onRequestCompleted(id: UUID, configs: APIClient.Configs) {}
}

public struct MultiplexAPIClientListener: APIClientListener {
	
	public var listeners: [APIClientListener]
	
	public init(_ listeners: [APIClientListener]) {
		self.listeners = listeners
	}
	
	public func onRequestStarted(id: UUID, request: HTTPRequestComponents, configs: APIClient.Configs) {
		listeners.forEach { $0.onRequestStarted(id: id, request: request, configs: configs) }
	}
	
	public func onResponseReceived<R>(id: UUID, response: R, configs: APIClient.Configs) {
		listeners.forEach { $0.onResponseReceived(id: id, response: response, configs: configs) }
	}
	
	public func onResponseSerialized<T>(id: UUID, response: T, configs: APIClient.Configs) {
		listeners.forEach { $0.onResponseSerialized(id: id, response: response, configs: configs) }
	}

	public func onRequestFailed(id: UUID, error: Error, configs: APIClient.Configs) {
		listeners.forEach { $0.onRequestFailed(id: id, error: error, configs: configs) }
	}

	public func onRequestCompleted(id: UUID, configs: APIClient.Configs) {
		listeners.forEach { $0.onRequestCompleted(id: id, configs: configs) }
	}
}

extension APIClient.Configs {

	public var listener: APIClientListener {
		get { self[\.listener] ?? MultiplexAPIClientListener([]) }
		set { self[\.listener] = newValue }
	}
}

extension APIClient {

	public func listener(_ listener: APIClientListener) -> APIClient {
		configs { configs in
			if var existingListener = configs.listener as? MultiplexAPIClientListener {
				existingListener.listeners.append(listener)
				configs.listener = existingListener
			} else {
				configs.listener = MultiplexAPIClientListener([configs.listener, listener])
			}
		}
	}
}
