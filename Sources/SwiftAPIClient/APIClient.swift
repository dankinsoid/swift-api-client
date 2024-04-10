@preconcurrency import Foundation
#if canImport(FoundationNetworking)
@_exported @preconcurrency import FoundationNetworking
#endif

/// A network client for handling url requests with configurable request and configuration handling.
public struct APIClient: @unchecked Sendable, RequestBuilder {

	private var _createRequest: (Configs) throws -> HTTPRequestComponents
	private var _modifyRequest: (inout HTTPRequestComponents, Configs) throws -> Void = { _, _ in }
	private var modifyConfigs: (inout Configs) -> Void = { _ in }

	/// Initializes a new network client with a closure that creates a URLRequest.
	/// - Parameter createRequest: A closure that takes `Configs` and returns a `HTTPRequestComponents`.
	public init(
		createRequest: @escaping (Configs) throws -> HTTPRequestComponents
	) {
		_createRequest = createRequest
	}

	/// Initializes a new network client with a closure that creates a URLRequest.
	/// - Parameter baseURL: A closure that takes `Configs` and returns a `URL`.
	public init(
		baseURL: @escaping (Configs) throws -> URL
	) {
		self.init {
			try HTTPRequestComponents(url: baseURL($0))
		}
	}

	/// Initializes a new network client with a base URL for requests.
	/// - Parameter baseURL: The base URL to be used for creating requests.
	public init(
		baseURL: URL
	) {
		self.init(request: HTTPRequestComponents(url: baseURL))
	}

	/// Initializes a new network client with a predefined URLRequest.
	/// - Parameter request: The URLRequest to be used for all requests.
	public init(
		request: HTTPRequestComponents
	) {
		self.init { _ in
			request
		}
	}

    /// Initializes a new network client with an empty request components.
    /// - Warning: You must specify the request components before making any requests.
    public init() {
        self.init { _ in
            HTTPRequestComponents()
        }
    }
    
    /// Initializes a new network client with a URL string.
    /// - Parameter string: The URL string to be used for creating requests.
    public init(string: String) {
        self.init { _ in
            guard let url = URL(string: string) else {
                throw Errors.custom("Invalid URL string: \(string)")
            }
            return HTTPRequestComponents(url: url)
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

	/// Modifies the URL request using the provided closure, with access to current configurations.
	/// - Parameter:
	///   - location: When the request should be modified.
	///   - modifier: A closure that takes `inout HTTPRequestComponents` and `Configs`, and modifies the URL request.
	/// - Returns: An instance of `APIClient` with a modified URL request.
	public func modifyRequest(
		_ modifier: @escaping (inout HTTPRequestComponents, Configs) throws -> Void
	) -> APIClient {
		var result = self
		result._createRequest = { [_createRequest] configs in
			var request = try _createRequest(configs)
			try modifier(&request, configs)
			return request
		}
		return result
	}

	/// Modifies the URL request using the provided closure before the request is executed.
	/// - Parameter modifier: A closure that takes `inout HTTPRequestComponents` and modifies the URL request.
	/// - Returns: An instance of `APIClient` with a modified URLRequest.
	public func finalizeRequest(
		_ modifier: @escaping (inout HTTPRequestComponents, Configs) throws -> Void
	) -> APIClient {
		var result = self
		result._modifyRequest = { [_modifyRequest] req, configs in
			try _modifyRequest(&req, configs)
			try modifier(&req, configs)
		}
		return result
	}

	/// Executes an operation with the current URL request and configurations.
	/// - Parameter operation: A closure that takes an URL request and `Configs` and returns a generic type `T`.
	/// - Throws: Rethrows any errors encountered within the closure.
	/// - Returns: The result of the closure of type `T`.
	public func withRequest<T>(_ operation: (HTTPRequestComponents, Configs) throws -> T) throws -> T {
		let (request, configs) = try createRequest()
		return try operation(request, configs)
	}

	/// Asynchronously executes an operation with the current URL request and configurations.
	/// - Parameter operation: A closure that takes an URL request and `Configs`, and returns a generic type `T`.
	/// - Throws: Rethrows any errors encountered within the closure.
	/// - Returns: The result of the closure of type `T`.
	public func withRequest<T>(_ operation: (HTTPRequestComponents, Configs) async throws -> T) async throws -> T {
		let (request, configs) = try createRequest()
		return try await operation(request, configs)
	}

	/// Build `HTTPRequestComponents`
	public func request() throws -> HTTPRequestComponents {
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

	private func createRequest() throws -> (HTTPRequestComponents, Configs) {
		var configs = Configs()
		let client = Self.globalModifier(self)
		client.modifyConfigs(&configs)
		var request = try client._createRequest(configs)
		try client._modifyRequest(&request, configs)
		return (request, configs)
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
		_ modifiers: @escaping @Sendable (APIClient) -> APIClient,
		operation: @Sendable () async throws -> T
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
	static var globalModifier: @Sendable (APIClient) -> APIClient = { $0 }
}
