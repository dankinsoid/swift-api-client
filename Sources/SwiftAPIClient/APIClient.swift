import Foundation
#if canImport(FoundationNetworking)
@_exported import FoundationNetworking
#endif

/// A network client for handling url requests with configurable request and configuration handling.
public struct APIClient {

	private var _createRequest: (Configs) throws -> HTTPRequest
	private var modifyConfigs: (inout Configs) -> Void = { _ in }

	/// Initializes a new network client with a closure that creates a URLRequest.
	/// - Parameter createRequest: A closure that takes `Configs` and returns a `HTTPRequest`.
	public init(
		createRequest: @escaping (Configs) throws -> HTTPRequest
	) {
		_createRequest = createRequest
	}

	/// Initializes a new network client with a closure that creates a URLRequest.
	/// - Parameter baseURL: A closure that takes `Configs` and returns a `URL`.
	public init(
		baseURL: @escaping (Configs) throws -> URL
	) {
		self.init {
			try HTTPRequest(url: baseURL($0))
		}
	}

	/// Initializes a new network client with a base URL for requests.
	/// - Parameter baseURL: The base URL to be used for creating requests.
	public init(
		baseURL: URL
	) {
		self.init(request: HTTPRequest(url: baseURL))
	}

	/// Initializes a new network client with a predefined URLRequest.
	/// - Parameter request: The URLRequest to be used for all requests.
	public init(
		request: HTTPRequest
	) {
		self.init { _ in
			request
		}
	}

	/// Configures the client with specific configuration values.
	/// - Parameters:
	///   - keyPath: The key path to the configuration property to be modified.
	///   - value: The new value for the specified configuration property.
	/// - Returns: An instance of `APIClient` with updated configurations.
	public func configs<T>(_ keyPath: WritableKeyPath<APIClient.Configs, T>, _ value: T) -> APIClient {
		configs {
			$0[keyPath: keyPath] = value
		}
	}

	/// Configures the client with a closure that modifies its configurations.
	/// - Parameter configs: A closure that takes `inout Configs` and modifies them.
	/// - Returns: An instance of `APIClient` with updated configurations.
	public func configs(_ configs: @escaping (inout Configs) -> Void) -> APIClient {
		var result = self
		result.modifyConfigs = { [modifyConfigs] in
			modifyConfigs(&$0)
			configs(&$0)
		}
		return result
	}

	/// Modifies the URLRequest using the provided closure.
	///   - location: When the request should be modified.
	///   - modifier: A closure that takes `inout URLRequest` and modifies the URLRequest.
	/// - Returns: An instance of `APIClient` with a modified URLRequest.
	public func modifyRequest(
		_ modifier: @escaping (inout HTTPRequest) throws -> Void
	) -> APIClient {
		modifyRequest { req, _ in
			try modifier(&req)
		}
	}

	/// Modifies the URLRequest using the provided closure, with access to current configurations.
	/// - Parameter:
	///   - location: When the request should be modified.
	///   - modifier: A closure that takes `inout URLRequest` and `Configs`, and modifies the URLRequest.
	/// - Returns: An instance of `APIClient` with a modified URLRequest.
	public func modifyRequest(
		_ modifier: @escaping (inout HTTPRequest, Configs) throws -> Void
	) -> APIClient {
		var result = self
		result._createRequest = { [_createRequest] configs in
			var request = try _createRequest(configs)
			try modifier(&request, configs)
			return request
		}
		return result
	}

	/// Executes an operation with the current URLRequest and configurations.
	/// - Parameter operation: A closure that takes an URL request and `Configs` and returns a generic type `T`.
	/// - Throws: Rethrows any errors encountered within the closure.
	/// - Returns: The result of the closure of type `T`.
	public func withRequest<T>(_ operation: (HTTPRequest, Configs) throws -> T) throws -> T {
		let (request, configs) = try createRequest()
		return try operation(request, configs)
	}

	/// Asynchronously executes an operation with the current URLRequest and configurations.
	/// - Parameter operation: A closure that takes an URL request and `Configs`, and returns a generic type `T`.
	/// - Throws: Rethrows any errors encountered within the closure.
	/// - Returns: The result of the closure of type `T`.
	public func withRequest<T>(_ operation: (HTTPRequest, Configs) async throws -> T) async throws -> T {
		let (request, configs) = try createRequest()
		return try await operation(request, configs)
	}

	/// Build `HTTPRequest`
	public func request() throws -> HTTPRequest {
		try withRequest { request, _ in request }
	}

	/// Executes an operation with the current configurations.
	/// - Parameter operation: A closure that takes `Configs` and returns a generic type `T`.
	/// - Rethrows: Rethrows any errors encountered within the closure.
	/// - Returns: The result of the closure of type `T`.
	public func withConfigs<T>(_ operation: (Configs) throws -> T) rethrows -> T {
		var configs = Configs()
		let client = Self.globalModifier(self)
		client.modifyConfigs(&configs)
		return try operation(configs)
	}

	/// Asynchronously executes an operation with the current configurations.
	/// - Parameter operation: A closure that takes `Configs` and returns a generic type `T`.
	/// - Rethrows: Rethrows any errors encountered within the closure.
	/// - Returns: The result of the closure of type `T`.
	public func withConfigs<T>(_ operation: (Configs) async throws -> T) async rethrows -> T {
		var configs = Configs()
		let client = Self.globalModifier(self)
		client.modifyConfigs(&configs)
		return try await operation(configs)
	}

    /// Modifies the client using the provided closure.
    public func modifier(_ modifier: (Self) throws -> Self) rethrows -> Self {
        try modifier(self)
    }

	private func createRequest() throws -> (HTTPRequest, Configs) {
		var configs = Configs()
		let client = Self.globalModifier(self)
		client.modifyConfigs(&configs)
		return try (client._createRequest(configs), configs)
	}
}

public extension APIClient {

	/// Set modifiers during the operation.
	///
	/// ```swift
	/// let url = try APIClient.withModifiers {
	///   $0.trackDownload { progress in ... }
	/// } operation: {
	///   try api().download(file: fileURL)
	/// }
	/// ```
	static func withModifiers<T>(
		_ modifiers: @escaping (APIClient) -> APIClient,
		operation: () throws -> T
	) rethrows -> T {
		let current = APIClient.globalModifier
		return try APIClient.$globalModifier.withValue(
			{ modifiers(current($0)) },
			operation: operation
		)
	}

	/// Set modifiers during the operation.
	///
	/// ```swift
	/// let url = try await APIClient.withModifiers {
	///   $0.trackDownload { progress in ... }
	/// } operation: {
	///   try await api().download(file: fileURL)
	/// }
	/// ```
	static func withModifiers<T>(
		_ modifiers: @escaping (APIClient) -> APIClient,
		operation: () async throws -> T
	) async rethrows -> T {
		let current = APIClient.globalModifier
		return try await APIClient.$globalModifier.withValue(
			{ modifiers(current($0)) },
			operation: operation
		)
	}
}

private extension APIClient {

	@TaskLocal
	static var globalModifier: (APIClient) -> APIClient = { $0 }
}
