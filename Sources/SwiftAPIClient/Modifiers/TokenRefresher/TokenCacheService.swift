import Foundation

/// A service for caching and retrieving secure data.
public protocol SecureCacheService {

	func load(for key: SecureCacheServiceKey) async throws -> String?
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

	func load(for key: SecureCacheServiceKey) async throws -> Date? {
		guard let dateString = try await load(for: key) else { return nil }
		return dateFormatter.date(from: dateString)
	}

	@_disfavoredOverload
	func save(_ value: Encodable?, for key: SecureCacheServiceKey, encoder: JSONEncoder = JSONEncoder()) async throws {
		guard let value else {
			try await save(nil as String?, for: key)
			return
		}
		let data = try encoder.encode(value)
		guard let string = String(data: data, encoding: .utf8) else { throw Errors.custom("Invalid UTF8 data") }
		try await save(string, for: key)
	}

	@_disfavoredOverload
	func load<T: Decodable>(for key: SecureCacheServiceKey, decoder: JSONDecoder = JSONDecoder()) async throws -> T? {
		guard let string = try await load(for: key) else { return nil }
		guard let data = string.data(using: .utf8) else { throw Errors.custom("Invalid UTF8 string") }
		return try decoder.decode(T.self, from: data)
	}
}

public final actor MockSecureCacheService: SecureCacheService {

	private var values: [SecureCacheServiceKey: String] = [:]

	public static let shared = MockSecureCacheService()

	public init(_ values: [SecureCacheServiceKey: String] = [:]) {
		self.values = values
	}

	public func load(for key: SecureCacheServiceKey) async throws -> String? {
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
#if canImport(UIKit)
import UIKit
#endif

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

	public func load(for key: SecureCacheServiceKey) async throws -> String? {

		// Create a query for retrieving the value
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: key.value,
			kSecReturnData as String: kCFBooleanTrue!,
			kSecMatchLimit as String: kSecMatchLimitOne,
		]
		configureAccess(query: &query)
		if let service {
			query[kSecAttrService as String] = service
		}

		var item: CFTypeRef?
		var status = SecItemCopyMatching(query as CFDictionary, &item)

		// Check the result

		if status == errSecInteractionNotAllowed {
			try await waitForProtectedDataAvailable()
			item = nil
			status = SecItemCopyMatching(query as CFDictionary, &item)
		}

		guard let data = item as? Data else {
			if [errSecItemNotFound, errSecNoSuchAttr, errSecNoSuchClass, errSecNoDefaultKeychain].contains(status) {
				return nil
			} else {
				throw Errors.custom("Failed to load the value from the Keychain. Status: \(status)")
			}
		}

		guard let token = String(data: data, encoding: .utf8) else {
			throw Errors.custom("Failed to convert the data to a string.")
		}

		return token
	}

	public func save(_ value: String?, for key: SecureCacheServiceKey) async throws {
		// Create a query for saving the token
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: key.value,
		]
		configureAccess(query: &query)

		if let service {
			query[kSecAttrService as String] = service
		}

		// Try to delete the old value if it exists
		SecItemDelete(query as CFDictionary)

		if let value {
			query[kSecValueData as String] = value.data(using: .utf8)
			// Add the new token to the Keychain
			var status = SecItemAdd(query as CFDictionary, nil)
			if status == errSecInteractionNotAllowed {
				try await waitForProtectedDataAvailable()
				status = SecItemAdd(query as CFDictionary, nil)
			}
			// Check the result
			guard status == noErr || status == errSecSuccess else {
				throw Errors.custom("Failed to save the value to the Keychain. Status: \(status)")
			}
		}
	}

	public func clear() async throws {
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
		]
		configureAccess(query: &query)

		if let service {
			query[kSecAttrService as String] = service
		}

		var status = SecItemDelete(query as CFDictionary)
		if status == errSecInteractionNotAllowed {
			try await waitForProtectedDataAvailable()
			status = SecItemDelete(query as CFDictionary)
		}

		guard status == noErr || status == errSecSuccess else {
			throw Errors.custom("Failed to clear the Keychain cache. Status: \(status)")
		}
	}

	private func configureAccess(query: inout [String: Any]) {
		query[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
		#if os(macOS)
		query[kSecUseDataProtectionKeychain as String] = true
		#endif
	}

	private func waitForProtectedDataAvailable() async throws {
		#if canImport(UIKit)
		guard await !UIApplication.shared.isProtectedDataAvailable else { return }
		let name = await UIApplication.protectedDataDidBecomeAvailableNotification
		let holder = Holder()
		try await withCheckedThrowingContinuation { continuation in
			Task {
				await holder.setContinuation(continuation)
				let observer = NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { _ in
					Task {
						await holder.resume()
					}
				}
				await holder.setObserver(observer)
			}
		}
		#endif
	}
}

#if canImport(UIKit)
private final actor Holder {

	var observer: NSObjectProtocol?
	var continuation: CheckedContinuation<Void, Error>?
	var task: Task<Void, Error>?

	func setObserver(_ observer: NSObjectProtocol) {
		if continuation != nil {
			self.observer = observer
		} else {
			NotificationCenter.default.removeObserver(observer)
		}
	}

	func setContinuation(_ continuation: CheckedContinuation<Void, Error>) {
		self.continuation = continuation
		task = Task { [weak self] in
			try await Task.sleep(nanoseconds: 60_000_000_000)
			await self?.resume(error: CancellationError())
		}
	}

	func resume(error: Error? = nil) {
		task?.cancel()
		task = nil
		if let error {
			continuation?.resume(throwing: error)
		} else {
			continuation?.resume()
		}
		continuation = nil
		if let observer {
			NotificationCenter.default.removeObserver(observer)
		}
		observer = nil
	}
}
#endif
#endif

private let dateFormatter: DateFormatter = {
	let formatter = DateFormatter()
	formatter.locale = Locale(identifier: "en_US_POSIX")
	formatter.timeZone = TimeZone(secondsFromGMT: 0)
	formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
	return formatter
}()
