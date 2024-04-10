@preconcurrency import Foundation

/// A service for caching and retrieving secure data.
public protocol SecureCacheService {

	subscript(key: SecureCacheServiceKey) -> String? { get nonmutating set }
	func clear() throws
}

/// A key for a secure cache service.
public struct SecureCacheServiceKey: Hashable, ExpressibleByStringInterpolation {

	public var value: String

	public init(_ value: String) {
		self.value = value
	}

	public init(stringLiteral value: String) {
		self.init(value)
	}

	public init(stringInterpolation: String.StringInterpolation) {
		self.init(String(stringInterpolation: stringInterpolation))
	}

	public static let accessToken: SecureCacheServiceKey = "accessToken"
	public static let refreshToken: SecureCacheServiceKey = "refreshToken"
	public static let expiryDate: SecureCacheServiceKey = "expiryDate"
}

public extension SecureCacheService where Self == MockSecureCacheService {

	/// A mock token cache service for testing.
	static var mock: MockSecureCacheService {
		.shared
	}
}

public final class MockSecureCacheService: SecureCacheService {

	private var values: [SecureCacheServiceKey: String] = [:]

	public static let shared = MockSecureCacheService()

	public subscript(key: SecureCacheServiceKey) -> String? {
		get { values[key] }
		set { values[key] = newValue }
	}

	public func clear() throws {}
}

#if canImport(Security)
import Security

public extension SecureCacheService where Self == KeychainCacheService {

	/// A Keychain token cache service with the default account and service.
	static var keychain: KeychainCacheService {
		.default
	}

	/// Creates a Keychain token cache service with the given account and service.
	/// - Parameters:
	///  - service: The service name.
	///
	/// `service` is used to differentiate between items stored in the Keychain.
	static func keychain(
		service: String? = nil
	) -> KeychainCacheService {
		KeychainCacheService(service: service)
	}
}

public struct KeychainCacheService: SecureCacheService {

	public let service: String?

	/// The default Keychain token cache service.
	public static var `default` = KeychainCacheService()

	public init(service: String? = nil) {
		self.service = service
	}

	public subscript(key: SecureCacheServiceKey) -> String? {
		get {
			// Create a query for retrieving the value
			var query: [String: Any] = [
				kSecClass as String: kSecClassGenericPassword,
				kSecAttrAccount as String: key.value,
				kSecReturnData as String: kCFBooleanTrue!,
				kSecMatchLimit as String: kSecMatchLimitOne,
			]
			if let service {
				query[kSecAttrService as String] = service
			}

			var item: CFTypeRef?
			let status = SecItemCopyMatching(query as CFDictionary, &item)

			// Check the result
			guard status == errSecSuccess, let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
				return nil
			}

			return token
		}
		nonmutating set {
			// Create a query for saving the token
			var query: [String: Any] = [
				kSecClass as String: kSecClassGenericPassword,
				kSecAttrAccount as String: key.value,
			]

			if let service {
				query[kSecAttrService as String] = service
			}

			// Try to delete the old value if it exists
			SecItemDelete(query as CFDictionary)

			if let newValue {
				query[kSecValueData as String] = newValue.data(using: .utf8)
				// Add the new token to the Keychain
				SecItemAdd(query as CFDictionary, nil)
				// Check the result
				// status == errSecSuccess
			}
		}
	}

	public func clear() throws {
		var query: [String: Any] = [kSecClass as String: kSecClassGenericPassword]

		if let service {
			query[kSecAttrService as String] = service
		}

		let status = SecItemDelete(query as CFDictionary)

		guard status == noErr || status == errSecSuccess else {
			throw Errors.custom("Failed to clear the Keychain cache.")
		}
	}
}
#endif
