import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient {

	/// Use this method to specify a mock response for a specific request.
	/// The usage of the mock is configured by the `usingMocks(policy:)` modifier.
	/// The default policy is `.ignore` for live environments and `.ifSpecified` for test and preview environments.
	/// You can set a value of either the response type or `Data`.
	///
	/// - Parameter value: The mock value to be returned for requests expecting a response of type `T`.
	/// - Returns: An instance of `APIClient` configured with the specified mock.
	///
	func mock<T>(_ value: T) -> APIClient {
		configs {
			$0.mocks[ObjectIdentifier(T.self)] = value
		}
	}

	/// Configures the client to use a specific policy for handling mocks.
	/// - Parameter policy: The `UsingMockPolicy` indicating how mocks should be used.
	/// - Returns: An instance of `APIClient` configured with the specified mock policy.
	func usingMocks(policy: UsingMocksPolicy) -> APIClient {
		configs(\.usingMocksPolicy, policy)
	}
}

public extension APIClient.Configs {

	/// The policy for using mock responses in the client.
	var usingMocksPolicy: UsingMocksPolicy {
		get { self[\.usingMocksPolicy] ?? valueFor(live: .ignore, test: .ifSpecified, preview: .ifSpecified) }
		set { self[\.usingMocksPolicy] = newValue }
	}

	/// Retrieves a mock response for the specified type if it exists.
	/// - Parameter type: The type for which to retrieve a mock response.
	/// - Returns: The mock response of the specified type, if it exists.
	func mock<T>(for type: T.Type) -> T? {
		(mocks[ObjectIdentifier(type)] as? T) ?? (type as? Mockable.Type)?.mock as? T
	}

	/// Returns a new configuration set with a specified mock response.
	/// - Parameters:
	///   - mock: The mock response to add to the configuration.
	/// - Returns: A new `APIClient.Configs` instance with the specified mock.
	func with<T>(mock: T) -> Self {
		var new = self
		new.mocks[ObjectIdentifier(T.self)] = mock
		return new
	}

	/// Retrieves a mock response if needed based on the current mock policy.
	/// - Parameter type: The type for which to retrieve a mock response.
	/// - Throws: An error if a required mock is missing.
	/// - Returns: The mock response of the specified type, if available and required by policy.
	func getMockIfNeeded<T>(for type: T.Type) throws -> T? {
		guard usingMocksPolicy != .ignore else { return nil }
		if let mock = mock(for: T.self) {
			return mock
		}
		if usingMocksPolicy == .require {
			throw Errors.mockIsMissed(type)
		}
		return nil
	}

	/// Retrieves a mock response if needed for a specific serializer, based on the current mock policy.
	/// - Parameters:
	///   - type: The type for which to retrieve a mock response.
	///   - serializer: A `Serializer` to process the mock response.
	/// - Throws: An error if a required mock is missing.
	/// - Returns: The mock response of the specified type, if available and required by policy.
	func getMockIfNeeded<Response, T>(for type: T.Type, serializer: Serializer<Response, T>) throws -> T? {
		guard usingMocksPolicy != .ignore else { return nil }
		if !(T.self is Response.Type), let mock = mock(for: T.self) {
			return mock
		}
		if let mockData = mock(for: Response.self) {
			return try serializer.serialize(mockData, self)
		}
		if usingMocksPolicy == .require {
			throw Errors.mockIsMissed(type)
		}
		return nil
	}
}

/// An enumeration defining policies for using mock responses.
public enum UsingMocksPolicy: Hashable {

	/// Ignores mock responses.
	case ignore
	/// Uses mock responses if they exist.
	case ifSpecified
	/// Requires the use of mock responses, throws error if not available./
	case require
}

private extension APIClient.Configs {

	var mocks: [ObjectIdentifier: Any] {
		get {
			self[\.mocks] ?? [
				ObjectIdentifier(Void.self) : (),
				ObjectIdentifier(Data.self) : "Mock data".data(using: .utf8) ?? Data(),
				ObjectIdentifier(String.self) : "Mock string"
			]
		}
		set {
			self[\.mocks] = newValue
		}
	}
}
