import Foundation

/// A service for caching and retrieving tokens.
public protocol TokenCacheService {

	func saveToken(_ token: String) throws
	func getToken() -> String?
	func clearToken() throws
}

public extension TokenCacheService where Self == MockTokenCacheService {

	/// A mock token cache service for testing.
	static var mock: MockTokenCacheService {
		MockTokenCacheService()
	}
}

public final class MockTokenCacheService: TokenCacheService {

	private var token: String?

	public static let shared = MockTokenCacheService()

	public func saveToken(_ token: String) throws {
		self.token = token
	}

	public func getToken() -> String? {
		token
	}

	public func clearToken() throws {
		token = nil
	}
}

#if canImport(Security)
import Security

public extension TokenCacheService where Self == KeychainTokenCacheService {

	/// A Keychain token cache service with the default account and service.
	static var keychain: KeychainTokenCacheService {
		KeychainTokenCacheService()
	}

	/// Creates a Keychain token cache service with the given account and service.
	/// - Parameters:
	///  - account: The account name.
	///  - service: The service name.
	///
	/// `account` and `service` are used to differentiate between items stored in the Keychain.
	static func keychain(
		account: String,
		service: String = "TokenCacheService"
	) -> KeychainTokenCacheService {
		KeychainTokenCacheService(account: account, service: service)
	}
}

public struct KeychainTokenCacheService: TokenCacheService {

	public let account: String
	public let service: String

	public init(
		account: String = "apiclient.token",
		service: String = "TokenCacheService"
	) {
		self.account = account
		self.service = service
	}

	public func saveToken(_ token: String) throws {
		// Create a query for saving the token
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: account,
			kSecAttrService as String: service,
			kSecValueData as String: token.data(using: .utf8)!,
		]

		// Try to delete the old token if it exists
		SecItemDelete(query as CFDictionary)

		// Add the new token to the Keychain
		let status = SecItemAdd(query as CFDictionary, nil)

		// Check the result
		guard status == errSecSuccess else {
			throw Errors.custom("Error saving the token to Keychain: \(status)")
		}
	}

	public func getToken() -> String? {
		// Create a query for retrieving the token
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: account,
			kSecAttrService as String: service,
			kSecReturnData as String: kCFBooleanTrue!,
			kSecMatchLimit as String: kSecMatchLimitOne,
		]

		var item: CFTypeRef?
		let status = SecItemCopyMatching(query as CFDictionary, &item)

		// Check the result
		guard status == errSecSuccess, let data = item as? Data, let token = String(data: data, encoding: .utf8) else {
			return nil
		}

		return token
	}

	public func clearToken() throws {
		// Create a query for deleting the token
		let query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: account,
			kSecAttrService as String: service,
		]

		// Delete the token from the Keychain
		let status = SecItemDelete(query as CFDictionary)

		guard status == errSecSuccess else {
			throw Errors.custom("Error clearing the token from Keychain: \(status)")
		}
	}
}
#endif
