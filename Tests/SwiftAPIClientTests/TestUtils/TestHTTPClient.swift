import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension HTTPClient {

	static func test() -> HTTPClient {
		HTTPClient { request, body, configs in
			try configs.testHTTPClient(request, body, configs)
		}
	}
}

private extension APIClient.Configs {

	var testHTTPClient: (HTTPRequest, RequestBody?, APIClient.Configs) throws -> (Data, HTTPResponse) {
		get { self[\.testHTTPClient] ?? { _, _, _ in throw Unimplemented() } }
		set { self[\.testHTTPClient] = newValue }
	}
}

private struct Unimplemented: Error {}

extension APIClient {

	@discardableResult
	func httpTest(
		test: @escaping (HTTPRequest, RequestBody?, APIClient.Configs) throws -> Void = { _, _, _ in }
	) async throws -> Data {
		try await httpTest {
			try test($0, $1, $2)
			return Data()
		}
	}

	@discardableResult
	func httpTest(
		test: @escaping (HTTPRequest, RequestBody?, APIClient.Configs) throws -> (Data, HTTPResponse)
	) async throws -> Data {
		try await configs(\.testHTTPClient) {
			try test($0, $1, $2)
		}
		.httpClient(.test())
		.call(.http)
	}

	@discardableResult
	func httpTest(
		test: @escaping (HTTPRequest, RequestBody?, APIClient.Configs) throws -> Data
	) async throws -> Data {
		try await httpTest {
			let data = try test($0, $1, $2)
            return (data, HTTPResponse(status: .ok))
		}
	}
}
