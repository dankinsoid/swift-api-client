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
  import CommonCrypto
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
    ///  - accessibility: When the stored values can be read. Defaults to `.afterFirstUnlock`.
    ///
    /// `service` is used to differentiate between items stored in the Keychain.
    public static func keychain(
      service: String? = nil,
      accessibility: KeychainCacheService.Accessibility = .afterFirstUnlock
    ) -> KeychainCacheService {
      KeychainCacheService(service: service, accessibility: accessibility)
    }
  }

  /// Stores values as Keychain generic passwords, one item per key.
  ///
  /// `saveTokens` stores the token set as one item and replaces it atomically;
  /// `saveTokens(_:replacingAccessToken:)` compares and replaces in a single Keychain update.
  /// Tokens saved per key by earlier versions are still read, and moved to the set on the next save.
  public struct KeychainCacheService: SecureCacheService {

    /// A `kSecAttrAccessible` value: when the stored values can be read.
    public struct Accessibility: Hashable, Sendable {

      public let rawValue: String

      public init(_ value: CFString) {
        rawValue = value as String
      }

      public static let afterFirstUnlock = Accessibility(kSecAttrAccessibleAfterFirstUnlock)
      public static let afterFirstUnlockThisDeviceOnly = Accessibility(kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly)
      public static let whenUnlocked = Accessibility(kSecAttrAccessibleWhenUnlocked)
      public static let whenUnlockedThisDeviceOnly = Accessibility(kSecAttrAccessibleWhenUnlockedThisDeviceOnly)
      public static let whenPasscodeSetThisDeviceOnly = Accessibility(kSecAttrAccessibleWhenPasscodeSetThisDeviceOnly)
    }

    public let service: String?

    /// Applied when a value is written; values are read regardless of the accessibility they were written with.
    public let accessibility: Accessibility

    /// The default Keychain token cache service.
    public static let `default` = KeychainCacheService()

    public init(service: String? = nil, accessibility: Accessibility = .afterFirstUnlock) {
      self.service = service
      self.accessibility = accessibility
    }

    public func load(for key: SecureCacheServiceKey) throws -> String? {
      if let field = StoredTokens.field(for: key) {
        var item: CFTypeRef?
        let status = SecItemCopyMatching(readQuery(account: Self.tokensAccount) as CFDictionary, &item)
        if let stored = try decodeTokens(data(from: item, status: status)) {
          return stored[keyPath: field]
        }
      }
      var item: CFTypeRef?
      let status = SecItemCopyMatching(readQuery(account: key.value) as CFDictionary, &item)
      return try string(from: data(from: item, status: status))
    }

    public func load(for key: SecureCacheServiceKey) async throws -> String? {
      if let field = StoredTokens.field(for: key), let stored = try await loadStoredTokens() {
        return stored[keyPath: field]
      }
      return try await string(from: read(account: key.value))
    }

    public func save(_ value: String?, for key: SecureCacheServiceKey) async throws {
      if let field = StoredTokens.field(for: key), var stored = try await loadStoredTokens() {
        stored[keyPath: field] = value
        _ = try await store(stored)
        return
      }
      try await write(value.map { Data($0.utf8) }, account: key.value)
    }

    public func clear() async throws {
      // Token items are removed whatever accessibility they were written with: clearing signs out.
      try await deleteLegacyTokens()
      try await delete(account: Self.tokensAccount)

      var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccessible as String: accessibility.rawValue,
      ]
      configureAccess(query: &query)

      let status = try await performWhenProtectedDataAvailable {
        SecItemDelete(query as CFDictionary)
      }
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw Errors.custom("Failed to clear the Keychain cache. Status: \(status)")
      }
    }

    public func loadTokens() async throws -> CachedTokens? {
      if let stored = try await loadStoredTokens() {
        return stored.cachedTokens
      }
      return try await loadLegacyTokens()
    }

    public func saveTokens(_ tokens: CachedTokens) async throws {
      _ = try await store(StoredTokens(tokens))
    }

    public func saveTokens(_ tokens: CachedTokens, replacingAccessToken accessToken: String) async throws -> Bool {
      if try await store(StoredTokens(tokens), replacingAccessToken: accessToken) {
        return true
      }
      // Tokens saved per key by an earlier version: compare and move them to the set in two steps, once.
      guard
        try await loadStoredTokens() == nil,
        try await string(from: read(account: SecureCacheServiceKey.accessToken.value)) == accessToken
      else {
        return false
      }
      return try await store(StoredTokens(tokens), addingOnly: true)
    }

    // MARK: - Token set

    private static let tokensAccount = "SwiftAPIClient.tokens"

    private struct StoredTokens: Codable, Equatable {

      var accessToken: String?
      var refreshToken: String?
      var expiryDate: String?

      init(_ tokens: CachedTokens) {
        accessToken = tokens.accessToken
        refreshToken = tokens.refreshToken
        expiryDate = tokens.expiryDate.map(DateFormatter.secureCacheService.string)
      }

      var cachedTokens: CachedTokens? {
        accessToken.map {
          CachedTokens(
            accessToken: $0,
            refreshToken: refreshToken,
            expiryDate: expiryDate.flatMap(DateFormatter.secureCacheService.date)
          )
        }
      }

      var isEmpty: Bool {
        accessToken == nil && refreshToken == nil && expiryDate == nil
      }

      static func field(for key: SecureCacheServiceKey) -> WritableKeyPath<StoredTokens, String?>? {
        switch key {
        case .accessToken: return \.accessToken
        case .refreshToken: return \.refreshToken
        case .expiryDate: return \.expiryDate
        default: return nil
        }
      }
    }

    private func loadStoredTokens() async throws -> StoredTokens? {
      try await decodeTokens(read(account: Self.tokensAccount))
    }

    private func decodeTokens(_ data: Data?) throws -> StoredTokens? {
      guard let data else { return nil }
      return try JSONDecoder().decode(StoredTokens.self, from: data)
    }

    /// Writes the set as one item and removes the per-key token items it supersedes.
    /// - Parameters:
    ///   - accessToken: Write only if the stored set holds this access token.
    ///   - addingOnly: Write only if there is no stored set.
    /// - Returns: `false` if a condition was not met and nothing was written.
    private func store(
      _ tokens: StoredTokens,
      replacingAccessToken accessToken: String? = nil,
      addingOnly: Bool = false
    ) async throws -> Bool {
      if tokens.isEmpty, accessToken == nil, !addingOnly {
        // Per-key items go first: once the set is gone, they would be read as current tokens.
        try await deleteLegacyTokens()
        try await delete(account: Self.tokensAccount)
        return true
      }

      let attributes: [String: Any] = [
        kSecValueData as String: try JSONEncoder().encode(tokens),
        // Lets `replacingAccessToken` compare inside the Keychain update.
        kSecAttrGeneric as String: Self.fingerprint(tokens.accessToken),
        kSecAttrAccessible as String: accessibility.rawValue,
      ]
      var query = readQuery(account: Self.tokensAccount, returningData: false)
      if let accessToken {
        query[kSecAttrGeneric as String] = Self.fingerprint(accessToken)
      }

      // A second round covers another writer adding the set between our update and add.
      for _ in 0 ..< 2 {
        if !addingOnly {
          let status = try await performWhenProtectedDataAvailable {
            SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
          }
          if status == errSecSuccess {
            try await deleteLegacyTokens()
            return true
          }
          guard status == errSecItemNotFound else {
            throw Errors.custom("Failed to save the tokens to the Keychain. Status: \(status)")
          }
          if accessToken != nil {
            return false
          }
        }

        let item = query.merging(attributes) { _, new in new }
        let status = try await performWhenProtectedDataAvailable {
          SecItemAdd(item as CFDictionary, nil)
        }
        if status == errSecSuccess {
          try await deleteLegacyTokens()
          return true
        }
        guard status == errSecDuplicateItem else {
          throw Errors.custom("Failed to save the tokens to the Keychain. Status: \(status)")
        }
        if addingOnly {
          return false
        }
      }
      throw Errors.custom("Failed to save the tokens to the Keychain. Status: \(errSecDuplicateItem)")
    }

    private func loadLegacyTokens() async throws -> CachedTokens? {
      // Access token first: earlier versions wrote it last.
      guard let accessToken = try await string(from: read(account: SecureCacheServiceKey.accessToken.value)) else {
        return nil
      }
      let refreshToken = try await string(from: read(account: SecureCacheServiceKey.refreshToken.value))
      let expiryDate = try await string(from: read(account: SecureCacheServiceKey.expiryDate.value))
      return CachedTokens(
        accessToken: accessToken,
        refreshToken: refreshToken,
        expiryDate: expiryDate.flatMap(DateFormatter.secureCacheService.date)
      )
    }

    private func deleteLegacyTokens() async throws {
      for key in [SecureCacheServiceKey.accessToken, .refreshToken, .expiryDate] {
        try await delete(account: key.value)
      }
    }

    private static func fingerprint(_ accessToken: String?) -> Data {
      guard let accessToken else { return Data() }
      let bytes = Array(accessToken.utf8)
      var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
      CC_SHA256(bytes, CC_LONG(bytes.count), &digest)
      return Data(digest)
    }

    // MARK: - Items

    private func read(account: String) async throws -> Data? {
      let query = readQuery(account: account)
      var item: CFTypeRef?
      let status = try await performWhenProtectedDataAvailable {
        SecItemCopyMatching(query as CFDictionary, &item)
      }
      return try data(from: item, status: status)
    }

    private func write(_ value: Data?, account: String) async throws {
      try await delete(account: account)
      guard let value else { return }
      var item = readQuery(account: account, returningData: false)
      item[kSecValueData as String] = value
      item[kSecAttrAccessible as String] = accessibility.rawValue
      let status = try await performWhenProtectedDataAvailable {
        SecItemAdd(item as CFDictionary, nil)
      }
      guard status == errSecSuccess else {
        throw Errors.custom("Failed to save the value to the Keychain. Status: \(status)")
      }
    }

    private func delete(account: String) async throws {
      let query = readQuery(account: account, returningData: false)
      let status = try await performWhenProtectedDataAvailable {
        SecItemDelete(query as CFDictionary)
      }
      guard status == errSecSuccess || status == errSecItemNotFound else {
        throw Errors.custom("Failed to delete the value from the Keychain. Status: \(status)")
      }
    }

    private func readQuery(account: String, returningData: Bool = true) -> [String: Any] {
      var query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: account,
      ]
      if returningData {
        query[kSecReturnData as String] = kCFBooleanTrue!
        query[kSecMatchLimit as String] = kSecMatchLimitOne
      }
      configureAccess(query: &query)
      return query
    }

    private func data(from item: CFTypeRef?, status: OSStatus) throws -> Data? {
      if let data = item as? Data {
        return data
      }
      if [errSecItemNotFound, errSecNoSuchAttr, errSecNoSuchClass, errSecNoDefaultKeychain].contains(status) {
        return nil
      }
      throw Errors.custom("Failed to load the value from the Keychain. Status: \(status)")
    }

    private func string(from data: Data?) throws -> String? {
      guard let data else { return nil }
      guard let value = String(data: data, encoding: .utf8) else {
        throw Errors.custom("Failed to convert the data to a string.")
      }
      return value
    }

    private func configureAccess(query: inout [String: Any]) {
      if let service {
        query[kSecAttrService as String] = service
      }
      #if os(macOS)
        query[kSecUseDataProtectionKeychain as String] = true
      #endif
    }

    private func performWhenProtectedDataAvailable(_ operation: () -> OSStatus) async throws -> OSStatus {
      let status = operation()
      guard status == errSecInteractionNotAllowed else { return status }
      try await waitForProtectedDataAvailable()
      return operation()
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
