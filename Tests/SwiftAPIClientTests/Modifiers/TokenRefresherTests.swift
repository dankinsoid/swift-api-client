import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class TokenRefresherTests: XCTestCase {

	// Unique per test: lineage and locks are process-wide.
	private let t1 = "t1-\(UUID().uuidString)"
	private let r1 = "r1-\(UUID().uuidString)"
	private let t2 = "t2-\(UUID().uuidString)"
	private let r2 = "r2-\(UUID().uuidString)"

	private let refreshes = Recorder<[String?]>([])

	private func client(
		cache: SecureCacheService,
		refresh: @escaping @Sendable (String?) async throws -> (String, String?, Date?)
	) -> APIClient {
		APIClient.test.tokenRefresher(cacheService: cache) { [refreshes] token, _, _ in
			refreshes.append(token)
			return try await refresh(token)
		}
	}

	private func signedIn(expiryDate: Date? = nil) async throws -> MockSecureCacheService {
		let cache = MockSecureCacheService()
		try await cache.saveTokens(CachedTokens(accessToken: t1, refreshToken: r1, expiryDate: expiryDate))
		return cache
	}

	func testExpiredStatusRefreshesAndRetries() async throws {
		let cache = try await signedIn()
		let sent = Recorder<[String?]>([])
		let body = try await client(cache: cache) { [t2, r2] _ in (t2, r2, nil) }
			.httpTest { [t1] request, _ in
				sent.append(request.bearerToken)
				return request.bearerToken == t1 ? respond(.unauthorized) : respond(.ok)
			}
		XCTAssertEqual(body, .okBody)
		XCTAssertEqual(sent.value, [t1, t2])
		XCTAssertEqual(refreshes.value, [r1])
		let tokens = try await cache.loadTokens()
		XCTAssertEqual(tokens, CachedTokens(accessToken: t2, refreshToken: r2))
	}

	func testRequestRejectedAfterAnotherRefreshRetriesWithoutRefreshingAgain() async throws {
		let cache = try await signedIn()
		let client = client(cache: cache) { [t2, r2] _ in (t2, r2, nil) }
		let sent = Recorder<[String?]>([])
		let body = try await client.path("a").httpTest { [t1] request, _ in
			sent.append(request.bearerToken)
			guard request.bearerToken == t1 else { return respond(.ok) }
			// Another request gets rejected and completes a refresh while this one is in flight.
			try await client.path("b").httpTest { request, _ in
				request.bearerToken == t1 ? respond(.unauthorized) : respond(.ok)
			}
			return respond(.unauthorized)
		}
		XCTAssertEqual(body, .okBody)
		XCTAssertEqual(sent.value, [t1, t2])
		XCTAssertEqual(refreshes.value, [r1])
	}

	func testConcurrentRejectionsShareOneRefresh() async throws {
		let cache = try await signedIn()
		let client = client(cache: cache) { [t2, r2] _ in
			try await Task.sleep(nanoseconds: 20_000_000)
			return (t2, r2, nil)
		}
		let sent = Recorder<[String?]>([])
		let server: @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (Data, HTTPResponse) = { [t1] request, _ in
			sent.append(request.bearerToken)
			guard request.bearerToken == t1 else { return respond(.ok) }
			// Rejects only once all requests are in flight with the expired token.
			for _ in 0 ..< 200 where sent.value.filter({ $0 == t1 }).count < 3 {
				try await Task.sleep(nanoseconds: 5_000_000)
			}
			return respond(.unauthorized)
		}
		async let first = client.httpTest(test: server)
		async let second = client.httpTest(test: server)
		async let third = client.httpTest(test: server)
		let bodies = try await [first, second, third]
		XCTAssertEqual(bodies, [.okBody, .okBody, .okBody])
		XCTAssertEqual(refreshes.value, [r1])
		XCTAssertEqual(sent.value.filter { $0 == t2 }.count, 3)
	}

	func testExpiryDateRefreshesOnceBeforeSending() async throws {
		let cache = try await signedIn(expiryDate: Date(timeIntervalSinceNow: -60))
		let client = client(cache: cache) { [t2, r2] _ in
			try await Task.sleep(nanoseconds: 20_000_000)
			return (t2, r2, Date(timeIntervalSinceNow: 3600))
		}
		let sent = Recorder<[String?]>([])
		let server: @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (Data, HTTPResponse) = { request, _ in
			sent.append(request.bearerToken)
			return respond(.ok)
		}
		async let first = client.httpTest(test: server)
		async let second = client.httpTest(test: server)
		_ = try await [first, second]
		try await client.httpTest(test: server)
		XCTAssertEqual(refreshes.value, [r1])
		XCTAssertEqual(sent.value, [t2, t2, t2])
	}

	func testRejectionAfterNewSignInIsReturnedWithoutRefreshOrRetry() async throws {
		let cache = try await signedIn()
		let other = CachedTokens(accessToken: "other-\(UUID().uuidString)", refreshToken: "other-refresh")
		let sent = Recorder<[String?]>([])
		let body = try await client(cache: cache) { [t2, r2] _ in (t2, r2, nil) }
			.httpTest { request, _ in
				sent.append(request.bearerToken)
				try await cache.saveTokens(other)
				return respond(.unauthorized)
			}
		XCTAssertEqual(body, .unauthorizedBody)
		XCTAssertEqual(sent.value, [t1])
		XCTAssertEqual(refreshes.value, [])
		let tokens = try await cache.loadTokens()
		XCTAssertEqual(tokens, other)
	}

	func testRejectionAfterSignOutIsReturnedWithoutRefresh() async throws {
		let cache = try await signedIn()
		let body = try await client(cache: cache) { [t2, r2] _ in (t2, r2, nil) }
			.httpTest { _, _ in
				try await cache.clear()
				return respond(.unauthorized)
			}
		XCTAssertEqual(body, .unauthorizedBody)
		XCTAssertEqual(refreshes.value, [])
		let tokens = try await cache.loadTokens()
		XCTAssertNil(tokens)
	}

	func testSignOutDuringRefreshKeepsCacheEmpty() async throws {
		let cache = try await signedIn()
		let sent = Recorder<[String?]>([])
		let body = try await client(cache: cache) { [t2, r2] _ in
			try await cache.clear()
			return (t2, r2, nil)
		}
		.httpTest { request, _ in
			sent.append(request.bearerToken)
			return respond(.unauthorized)
		}
		XCTAssertEqual(body, .unauthorizedBody)
		XCTAssertEqual(sent.value, [t1])
		let tokens = try await cache.loadTokens()
		XCTAssertNil(tokens)
	}

	func testFailedRefreshKeepsTokens() async throws {
		let cache = try await signedIn()
		do {
			try await client(cache: cache) { _ in throw URLError(.notConnectedToInternet) }
				.httpTest { _, _ in respond(.unauthorized) }
			XCTFail("Expected an error")
		} catch {
			XCTAssertEqual((error as? URLError)?.code, .notConnectedToInternet)
		}
		let tokens = try await cache.loadTokens()
		XCTAssertEqual(tokens, CachedTokens(accessToken: t1, refreshToken: r1))
	}

	func testRefreshedTokensAreSavedAsOneSet() async throws {
		let cache = AtomicCache()
		try await cache.saveTokens(CachedTokens(accessToken: t1, refreshToken: r1))
		await cache.base.reset()
		// No refresh token in the response: the backend does not rotate it.
		try await client(cache: cache) { [t2] _ in (t2, nil, nil) }
			.httpTest { [t1] request, _ in request.bearerToken == t1 ? respond(.unauthorized) : respond(.ok) }
		let operations = await cache.base.operations
		XCTAssertEqual(operations.first, "saveTokens \(t2) \(r1) nil")
		XCTAssertFalse(operations.dropFirst().contains { $0.hasPrefix("saveTokens") })
	}

	func testDefaultSaveTokensWritesAccessTokenLast() async throws {
		let cache = RecordingCache()
		let expiryDate = Date(timeIntervalSince1970: 0)
		try await cache.saveTokens(CachedTokens(accessToken: t2, refreshToken: nil, expiryDate: expiryDate))
		let operations = await cache.operations
		XCTAssertEqual(operations, [
			"save refreshToken nil",
			"save expiryDate \(DateFormatter.secureCacheService.string(from: expiryDate))",
			"save accessToken \(t2)",
		])
		let tokens = try await cache.loadTokens()
		XCTAssertEqual(tokens, CachedTokens(accessToken: t2, refreshToken: nil, expiryDate: expiryDate))
	}

	func testConditionalSaveKeepsTokensItDoesNotReplace() async throws {
		let caches: [SecureCacheService] = [MockSecureCacheService(), RecordingCache()]
		for cache in caches {
			try await cache.saveTokens(CachedTokens(accessToken: t1, refreshToken: r1))
			let skipped = try await cache.saveTokens(CachedTokens(accessToken: t2), replacingAccessToken: "other")
			XCTAssertFalse(skipped)
			let saved = try await cache.saveTokens(CachedTokens(accessToken: t2, refreshToken: r2), replacingAccessToken: t1)
			XCTAssertTrue(saved)
			let tokens = try await cache.loadTokens()
			XCTAssertEqual(tokens, CachedTokens(accessToken: t2, refreshToken: r2))
		}
	}

	func testRequestedTokensAreCached() async throws {
		let cache = MockSecureCacheService()
		let requests = Recorder(0)
		let client = APIClient.test.tokenRefresher(
			cacheService: cache,
			request: { [t1, r1] _, _ in
				requests.mutate { $0 += 1 }
				return (t1, r1, nil)
			},
			refresh: { [t2, r2] _, _, _ in (t2, r2, nil) }
		)
		try await client.httpTest { _, _ in respond(.ok) }
		try await client.httpTest { _, _ in respond(.ok) }
		XCTAssertEqual(requests.value, 1)
		let tokens = try await cache.loadTokens()
		XCTAssertEqual(tokens, CachedTokens(accessToken: t1, refreshToken: r1))
	}

	func testErrorHandlerSeesAccessTokenOfFailedAttempt() async throws {
		let cache = try await signedIn()
		let handled = Recorder<[String?]>([])
		let client = client(cache: cache) { [t2, r2] _ in (t2, r2, nil) }
			.httpResponseValidator(.statusCode)
			.errorHandler { _, _, context in handled.append(context.accessToken) }

		_ = try? await client.httpTest { _, _ in respond(.unauthorized) }
		_ = try? await client.httpTest { _, _ -> Data in throw URLError(.notConnectedToInternet) }
		_ = try? await APIClient.test
			.httpResponseValidator(.statusCode)
			.errorHandler { _, _, context in handled.append(context.accessToken) }
			.httpTest { _, _ in respond(.unauthorized) }

		XCTAssertEqual(handled.value, [t2, t2, nil])
	}
}

private extension HTTPRequestComponents {

	var bearerToken: String? {
		headers[.authorization].map { String($0.dropFirst("Bearer ".count)) }
	}
}

private extension Data {

	static let okBody = Data("ok".utf8)
	static let unauthorizedBody = Data("unauthorized".utf8)
}

private func respond(_ status: HTTPResponse.Status) -> (Data, HTTPResponse) {
	(status == .ok ? .okBody : .unauthorizedBody, HTTPResponse(status: status))
}

private final class Recorder<Value>: @unchecked Sendable {

	private let lock = NSLock()
	private var _value: Value

	init(_ value: Value) {
		_value = value
	}

	var value: Value {
		lock.lock()
		defer { lock.unlock() }
		return _value
	}

	func mutate(_ body: (inout Value) -> Void) {
		lock.lock()
		defer { lock.unlock() }
		body(&_value)
	}
}

private extension Recorder where Value == [String?] {

	func append(_ element: String?) {
		mutate { $0.append(element) }
	}
}

/// Uses the protocol's default `saveTokens`.
private final actor RecordingCache: SecureCacheService {

	private var values: [SecureCacheServiceKey: String] = [:]
	private(set) var operations: [String] = []

	func record(_ operation: String) {
		operations.append(operation)
	}

	func reset() {
		operations = []
	}

	func load(for key: SecureCacheServiceKey) async throws -> String? {
		values[key]
	}

	func save(_ value: String?, for key: SecureCacheServiceKey) async throws {
		operations.append("save \(key) \(value ?? "nil")")
		values[key] = value
	}

	func clear() async throws {
		values = [:]
	}
}

private struct AtomicCache: SecureCacheService {

	let base = RecordingCache()

	func load(for key: SecureCacheServiceKey) async throws -> String? {
		try await base.load(for: key)
	}

	func save(_ value: String?, for key: SecureCacheServiceKey) async throws {
		try await base.save(value, for: key)
	}

	func clear() async throws {
		try await base.clear()
	}

	func saveTokens(_ tokens: CachedTokens) async throws {
		await base.record("saveTokens \(tokens.accessToken) \(tokens.refreshToken ?? "nil") \(tokens.expiryDate.map { "\($0)" } ?? "nil")")
		try await base.save(tokens.refreshToken, for: .refreshToken)
		try await base.save(tokens.expiryDate, for: .expiryDate)
		try await base.save(tokens.accessToken, for: .accessToken)
	}
}
