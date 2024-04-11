import Foundation

/// A service for caching and retrieving secure data.
public protocol SecureCacheService {

    func load(for key: SecureCacheServiceKey) async -> String?
    func save(_ value: String?, for key: SecureCacheServiceKey) async throws
	func clear() async throws
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

public extension SecureCacheService {

    func save(_ date: Date?, for key: SecureCacheServiceKey) async throws {
        try await save(date.map(dateFormatter.string), for: key)
    }

    func load(for key: SecureCacheServiceKey) async -> Date? {
        guard let dateString = await load(for: key) else { return nil }
        return dateFormatter.date(from: dateString)
    }
}

public final actor MockSecureCacheService: SecureCacheService {

	private var values: [SecureCacheServiceKey: String] = [:]

	public static let shared = MockSecureCacheService()

    public init(_ values: [SecureCacheServiceKey: String] = [:]) {
        self.values = values
    }

    public func load(for key: SecureCacheServiceKey) async -> String? {
        values[key]
    }
    public func save(_ value: String?, for key: SecureCacheServiceKey) async throws {
        values[key] = value
    }

	public func clear() async throws {
        values.removeAll()
    }
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

    public func load(for key: SecureCacheServiceKey) async -> String? {
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
    
    public func save(_ value: String?, for key: SecureCacheServiceKey) async throws {
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
        
        if let value {
            query[kSecValueData as String] = value.data(using: .utf8)
            // Add the new token to the Keychain
            SecItemAdd(query as CFDictionary, nil)
            // Check the result
            // status == errSecSuccess
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

private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return formatter
}()
