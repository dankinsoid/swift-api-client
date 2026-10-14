import Foundation

/// A service for caching and retrieving secure data.
public protocol SecureCacheService: Sendable {

  func load(for key: SecureCacheServiceKey) async throws -> String?
  func save(_ value: String?, for key: SecureCacheServiceKey) async throws
  func clear() async throws

  /// Loads the tokens stored under `.accessToken`, `.refreshToken` and `.expiryDate` as one set.
  /// Returns `nil` when there is no access token.
  func loadTokens() async throws -> CachedTokens?

  /// Replaces the tokens stored under `.accessToken`, `.refreshToken` and `.expiryDate`; `nil` fields are removed.
  ///
  /// The default implementation writes key by key, access token last.
  /// Override it to write the set atomically when the storage allows it.
  func saveTokens(_ tokens: CachedTokens) async throws

  /// Saves `tokens` refreshed from `accessToken` if it is still the cached access token.
  /// Returns `false` without saving otherwise: a sign-out or another sign-in during the refresh wins.
  ///
  /// The default implementation compares and saves in two steps.
  /// Override it to do both atomically, so a concurrent sign-out cannot be overwritten.
  func saveTokens(_ tokens: CachedTokens, replacingAccessToken accessToken: String) async throws -> Bool
}

/// The tokens `TokenRefresherMiddleware` authorizes requests with.
public struct CachedTokens: Hashable, Sendable {

  public var accessToken: String
  public var refreshToken: String?
  public var expiryDate: Date?

  public init(accessToken: String, refreshToken: String? = nil, expiryDate: Date? = nil) {
    self.accessToken = accessToken
    self.refreshToken = refreshToken
    self.expiryDate = expiryDate
  }
}

/// A key for a secure cache service.
public struct SecureCacheServiceKey: Hashable, ExpressibleByStringInterpolation,
  LosslessStringConvertible, CodingKeyRepresentable, CodingKey, Sendable
{

  public var value: String
  public var description: String { value }
  public var stringValue: String { value }
  public var intValue: Int? { nil }
  public var codingKey: any CodingKey { self }

  public init(_ value: String) {
    self.value = value
  }

  public init(stringLiteral value: String) {
    self.init(value)
  }

  public init(stringValue: String) {
    self.init(stringValue)
  }

  public init?(intValue: Int) {
    return nil
  }

  public init<T: CodingKey>(codingKey: T) {
    self.init(codingKey.stringValue)
  }

  public init(stringInterpolation: String.StringInterpolation) {
    self.init(String(stringInterpolation: stringInterpolation))
  }

  public static let accessToken: SecureCacheServiceKey = "accessToken"
  public static let refreshToken: SecureCacheServiceKey = "refreshToken"
  public static let expiryDate: SecureCacheServiceKey = "expiryDate"
}

extension SecureCacheService where Self == MockSecureCacheService {

  /// A mock token cache service for testing.
  public static var mock: MockSecureCacheService {
    .shared
  }
}

extension SecureCacheService {

  public func loadTokens() async throws -> CachedTokens? {
    // Access token first: `saveTokens` writes it last, so the refresh token read next is never older.
    guard let accessToken: String = try await load(for: .accessToken) else { return nil }
    let refreshToken: String? = try await load(for: .refreshToken)
    let expiryDate: Date? = try await load(for: .expiryDate)
    return CachedTokens(accessToken: accessToken, refreshToken: refreshToken, expiryDate: expiryDate)
  }

  public func saveTokens(_ tokens: CachedTokens) async throws {
    // A crash between writes leaves the old access token with the new refresh token, which still refreshes.
    try await save(tokens.refreshToken, for: .refreshToken)
    try await save(tokens.expiryDate, for: .expiryDate)
    try await save(tokens.accessToken, for: .accessToken)
  }

  public func saveTokens(_ tokens: CachedTokens, replacingAccessToken accessToken: String) async throws -> Bool {
    guard try await load(for: .accessToken) == accessToken else { return false }
    try await saveTokens(tokens)
    return true
  }

  public func save(_ date: Date?, for key: SecureCacheServiceKey) async throws {
    try await save(date.map(DateFormatter.secureCacheService.string), for: key)
  }

  public func load(for key: SecureCacheServiceKey) async throws -> Date? {
    guard let dateString = try await load(for: key) else { return nil }
    return DateFormatter.secureCacheService.date(from: dateString)
  }

  @_disfavoredOverload
  public func save(
    _ value: Encodable?, for key: SecureCacheServiceKey, encoder: JSONEncoder = JSONEncoder()
  ) async throws {
    guard let value else {
      try await save(nil as String?, for: key)
      return
    }
    let data = try encoder.encode(value)
    guard let string = String(data: data, encoding: .utf8) else {
      throw Errors.custom("Invalid UTF8 data")
    }
    try await save(string, for: key)
  }

  @_disfavoredOverload
  public func load<T: Decodable>(
    for key: SecureCacheServiceKey, decoder: JSONDecoder = JSONDecoder()
  ) async throws -> T? {
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

  public func loadTokens() async throws -> CachedTokens? {
    guard let accessToken = values[.accessToken] else { return nil }
    return CachedTokens(
      accessToken: accessToken,
      refreshToken: values[.refreshToken],
      expiryDate: values[.expiryDate].flatMap(DateFormatter.secureCacheService.date)
    )
  }

  public func saveTokens(_ tokens: CachedTokens) async throws {
    store(tokens)
  }

  public func saveTokens(_ tokens: CachedTokens, replacingAccessToken accessToken: String) async throws -> Bool {
    guard values[.accessToken] == accessToken else { return false }
    store(tokens)
    return true
  }

  private func store(_ tokens: CachedTokens) {
    values[.accessToken] = tokens.accessToken
    values[.refreshToken] = tokens.refreshToken
    values[.expiryDate] = tokens.expiryDate.map(DateFormatter.secureCacheService.string)
  }
}

#if canImport(Security)
  import Security
  #if canImport(UIKit)
    import UIKit
  #endif

  extension SecureCacheService where Self == KeychainCacheService {

    /// A Keychain token cache service with the default account and service.
    public static var keychain: KeychainCacheService {
      .default
    }

    /// Creates a Keychain token cache service with the given account and service.
    /// - Parameters:
    ///  - service: The service name.
    ///
    /// `service` is used to differentiate between items stored in the Keychain.
    public static func keychain(
      service: String? = nil
    ) -> KeychainCacheService {
      KeychainCacheService(service: service)
    }
  }

  public struct KeychainCacheService: SecureCacheService {

    public let service: String?

    /// The default Keychain token cache service.
    public static let `default` = KeychainCacheService()

    public init(service: String? = nil) {
      self.service = service
    }

    public func load(for key: SecureCacheServiceKey) throws -> String? {
      let (_, item, status) = loadStatus(for: key)
      return try load(item: item, status: status)
    }

    public func load(for key: SecureCacheServiceKey) async throws -> String? {

      var (query, item, status) = loadStatus(for: key)

      // Check the result

      if status == errSecInteractionNotAllowed {
        try await waitForProtectedDataAvailable()
        item = nil
        status = SecItemCopyMatching(query as CFDictionary, &item)
      }

      return try load(item: item, status: status)
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
        kSecClass as String: kSecClassGenericPassword
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

    private func loadStatus(for key: SecureCacheServiceKey) -> ([String: Any], CFTypeRef?, OSStatus)
    {
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
      let status = SecItemCopyMatching(query as CFDictionary, &item)
      return (query, item, status)
    }

    private func load(item: CFTypeRef?, status: OSStatus) throws -> String? {
      guard let data = item as? Data else {
        if [errSecItemNotFound, errSecNoSuchAttr, errSecNoSuchClass, errSecNoDefaultKeychain]
          .contains(status)
        {
          return nil
        } else {
          throw Errors.custom("Failed to load the value from the Keychain. Status: \(status)")
        }
      }

      guard let value = String(data: data, encoding: .utf8) else {
        throw Errors.custom("Failed to convert the data to a string.")
      }

      return value
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
        let name = UIApplication.protectedDataDidBecomeAvailableNotification
        let holder = Holder()
        try await withCheckedThrowingContinuation { continuation in
          Task {
            await holder.setContinuation(continuation)
            let observer = NotificationCenter.default.addObserver(
              forName: name, object: nil, queue: .main
            ) { _ in
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

extension DateFormatter {

  /// A date formatter for the secure cache service to format dates.
  public static let secureCacheService: DateFormatter = {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
    return formatter
  }()
}
