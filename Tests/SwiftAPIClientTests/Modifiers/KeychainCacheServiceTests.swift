#if canImport(Security)
import Foundation
import Security
@testable import SwiftAPIClient
import XCTest

final class KeychainCacheServiceTests: XCTestCase {

	private var service = ""
	private var cache: KeychainCacheService { KeychainCacheService(service: service) }

	override func setUp() async throws {
		service = "SwiftAPIClientTests.\(UUID().uuidString)"
		do {
			try await cache.save("probe", for: "probe")
			try await cache.save(nil, for: "probe")
		} catch {
			// Needs a keychain entitlement: unavailable to `swift test`, available to tests hosted in an app.
			throw XCTSkip("Keychain is unavailable: \(error)")
		}
	}

	override func tearDown() async throws {
		try? await cache.clear()
	}

	func testTokensRoundTripAsOneItem() async throws {
		let tokens = CachedTokens(accessToken: "access", refreshToken: "refresh", expiryDate: Date(timeIntervalSince1970: 1000))

		try await cache.saveTokens(tokens)

		let loaded = try await cache.loadTokens()
		XCTAssertEqual(loaded, tokens)
		XCTAssertNotNil(rawItem(account: "SwiftAPIClient.tokens"))
		XCTAssertNil(rawItem(account: "accessToken"))
		let accessToken: String? = try await cache.load(for: .accessToken)
		XCTAssertEqual(accessToken, "access")
		XCTAssertEqual(try loadSynchronously(.refreshToken), "refresh")
	}

	func testTokensSavedPerKeyAreReadAndMovedToTheSet() async throws {
		try await cache.save("old-refresh", for: .refreshToken)
		try await cache.save("old-access", for: .accessToken)
		XCTAssertNotNil(rawItem(account: "accessToken"))

		let legacy = try await cache.loadTokens()
		XCTAssertEqual(legacy, CachedTokens(accessToken: "old-access", refreshToken: "old-refresh"))

		let renewed = CachedTokens(accessToken: "new-access", refreshToken: "new-refresh")
		let replaced = try await cache.saveTokens(renewed, replacingAccessToken: "old-access")

		XCTAssertTrue(replaced)
		let loaded = try await cache.loadTokens()
		XCTAssertEqual(loaded, renewed)
		XCTAssertNil(rawItem(account: "accessToken"))
		XCTAssertNil(rawItem(account: "refreshToken"))
	}

	func testReplacingComparesTheAccessToken() async throws {
		let current = CachedTokens(accessToken: "current", refreshToken: "refresh")
		try await cache.saveTokens(current)

		let stale = try await cache.saveTokens(CachedTokens(accessToken: "x"), replacingAccessToken: "other")
		XCTAssertFalse(stale)
		let unchanged = try await cache.loadTokens()
		XCTAssertEqual(unchanged, current)

		let renewed = CachedTokens(accessToken: "renewed", refreshToken: "refresh-2")
		let replaced = try await cache.saveTokens(renewed, replacingAccessToken: "current")
		XCTAssertTrue(replaced)
		let loaded = try await cache.loadTokens()
		XCTAssertEqual(loaded, renewed)
	}

	func testReplacingFailsWithoutTokens() async throws {
		let replaced = try await cache.saveTokens(CachedTokens(accessToken: "new"), replacingAccessToken: "old")
		XCTAssertFalse(replaced)
		let loaded = try await cache.loadTokens()
		XCTAssertNil(loaded)
	}

	func testPerKeySavesUpdateTheSet() async throws {
		try await cache.saveTokens(CachedTokens(accessToken: "access", refreshToken: "refresh"))

		try await cache.save("access-2", for: .accessToken)
		let updated = try await cache.loadTokens()
		XCTAssertEqual(updated, CachedTokens(accessToken: "access-2", refreshToken: "refresh"))

		try await cache.save(nil, for: .accessToken)
		let signedOut = try await cache.loadTokens()
		XCTAssertNil(signedOut)

		try await cache.save(nil, for: .refreshToken)
		XCTAssertNil(rawItem(account: "SwiftAPIClient.tokens"))
	}

	func testClearRemovesTokens() async throws {
		try await cache.saveTokens(CachedTokens(accessToken: "access"))
		try await cache.save("value", for: "other")

		try await cache.clear()

		let tokens = try await cache.loadTokens()
		XCTAssertNil(tokens)
		let other: String? = try await cache.load(for: "other")
		XCTAssertNil(other)
	}

	func testAccessibilityIsAppliedAndCanChange() async throws {
		try await cache.saveTokens(CachedTokens(accessToken: "access"))
		XCTAssertEqual(accessible(account: "SwiftAPIClient.tokens"), kSecAttrAccessibleAfterFirstUnlock as String)

		let stricter = KeychainCacheService(service: service, accessibility: .whenUnlockedThisDeviceOnly)
		let loaded = try await stricter.loadTokens()
		XCTAssertEqual(loaded?.accessToken, "access")

		try await stricter.saveTokens(CachedTokens(accessToken: "access-2"))
		try await stricter.save("value", for: "other")
		try await stricter.save("value-2", for: "other")

		XCTAssertEqual(accessible(account: "SwiftAPIClient.tokens"), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
		XCTAssertEqual(accessible(account: "other"), kSecAttrAccessibleWhenUnlockedThisDeviceOnly as String)
		let other: String? = try await cache.load(for: "other")
		XCTAssertEqual(other, "value-2")
		try await stricter.clear()
	}

	private func loadSynchronously(_ key: SecureCacheServiceKey) throws -> String? {
		try cache.load(for: key)
	}

	private func rawItem(account: String) -> [String: Any]? {
		var query: [String: Any] = [
			kSecClass as String: kSecClassGenericPassword,
			kSecAttrAccount as String: account,
			kSecAttrService as String: service,
			kSecReturnAttributes as String: true,
			kSecMatchLimit as String: kSecMatchLimitOne,
		]
		#if os(macOS)
		query[kSecUseDataProtectionKeychain as String] = true
		#endif
		var item: CFTypeRef?
		guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess else { return nil }
		return item as? [String: Any]
	}

	private func accessible(account: String) -> String? {
		rawItem(account: account)?[kSecAttrAccessible as String] as? String
	}
}
#endif
