import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import XCTest

final class ErrorHandlerTests: XCTestCase {

	func testContextKeepsStatusWithoutHTTPResponse() {
		let context = APIErrorContext(status: .notFound, fileID: #fileID, line: #line)
		XCTAssertEqual(context.status, .notFound)
	}

	func testContextStatusFallsBackToHTTPResponse() {
		let context = APIErrorContext(httpResponse: HTTPResponse(status: .conflict), codeLocation: CodeLocation())
		XCTAssertEqual(context.status, .conflict)
	}

	func testHandlerReceivesResponseStatus() async {
		let status = Locked<HTTPResponse.Status?>(nil)
		_ = try? await APIClient.failing
			.errorHandler { _, _, context in status.value = context.status }
			.httpTest { _, _ in (Data(), HTTPResponse(status: .notFound)) }
		XCTAssertEqual(status.value, .notFound)
	}

	func testAppendedHandlerRuns() async {
		let handled = Locked(false)
		_ = try? await APIClient.failing
			.errorHandler(insertingBeforeExisting: false) { _, _, _ in handled.value = true }
			.httpTest { _, _ in (Data(), HTTPResponse(status: .notFound)) }
		XCTAssertTrue(handled.value)
	}

	func testDetailedErrorWrapsError() async throws {
		do {
			try await APIClient.failing
				.detailedError()
				.httpTest { _, _ in (Data(), HTTPResponse(status: .notFound)) }
			XCTFail("Expected an error")
		} catch {
			XCTAssertTrue(error is APIClientError, "\(error)")
		}
	}

	func testHandlersRunInOrderAndSeeReplacedError() async throws {
		let calls = Locked<[String]>([])
		do {
			try await APIClient.failing
				.errorHandler { _, _, _ in
					calls.value.append("first")
					throw Replaced(name: "first")
				}
				.errorHandler { error, _, _ in
					calls.value.append("second:\((error as? Replaced)?.name ?? "\(error)")")
				}
				.errorHandler(insertingBeforeExisting: true) { _, _, _ in
					calls.value.append("inserted")
				}
				.httpTest { _, _ in (Data(), HTTPResponse(status: .notFound)) }
			XCTFail("Expected an error")
		} catch {
			XCTAssertEqual((error as? Replaced)?.name, "first")
		}
		XCTAssertEqual(calls.value, ["inserted", "first", "second:first"])
	}

	func testLaterThrowWins() async throws {
		do {
			try await APIClient.failing
				.errorHandler { _, _, _ in throw Replaced(name: "first") }
				.errorHandler { _, _, _ in throw Replaced(name: "second") }
				.httpTest { _, _ in (Data(), HTTPResponse(status: .notFound)) }
			XCTFail("Expected an error")
		} catch {
			XCTAssertEqual((error as? Replaced)?.name, "second")
		}
	}

	func testHandlerRunsOnceForSynchronousCaller() throws {
		let count = Locked(0)
		XCTAssertThrowsError(
			try APIClient.test
				.errorHandler { _, _, _ in count.value += 1 }
				.call(.mock(Data("{}".utf8)), as: .decodable(FakeResponse.self))
		)
		XCTAssertEqual(count.value, 1)
	}
}

private extension APIClient {

	static var failing: APIClient {
		APIClient.test.httpResponseValidator(.statusCode)
	}
}

private struct Replaced: Error {

	var name: String
}

private final class Locked<Value>: @unchecked Sendable {

	private let lock = NSLock()
	private var _value: Value

	init(_ value: Value) {
		_value = value
	}

	var value: Value {
		get { lock.lock(); defer { lock.unlock() }; return _value }
		set { lock.lock(); defer { lock.unlock() }; _value = newValue }
	}
}
