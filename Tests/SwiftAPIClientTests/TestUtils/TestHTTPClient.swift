import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension HTTPClient {

	static func test() -> HTTPClient {
		HTTPClient { request, _, configs in
            try configs.testHTTPClient(request, configs)
		}
	}
}

private extension APIClient.Configs {

	var testHTTPClient: (URLRequest, APIClient.Configs) throws -> (Data, HTTPURLResponse) {
		get { self[\.testHTTPClient] ?? { _, _ in throw Unimplemented() } }
		set { self[\.testHTTPClient] = newValue }
	}
}

private struct Unimplemented: Error {}

extension APIClient {

	@discardableResult
	func httpTest(
		test: @escaping (URLRequest, APIClient.Configs) throws -> Void = { _, _ in }
	) async throws -> Data {
		try await httpTest {
			try test($0, $1)
			return Data()
		}
	}

	@discardableResult
	func httpTest(
		test: @escaping (URLRequest, APIClient.Configs) throws -> (Data, HTTPURLResponse)
	) async throws -> Data {
		try await configs(\.testHTTPClient) {
			try test($0, $1)
		}
		.httpClient(.test())
		.call(.http)
	}

	@discardableResult
	func httpTest(
		test: @escaping (URLRequest, APIClient.Configs) throws -> Data
	) async throws -> Data {
		try await httpTest {
			let data = try test($0, $1)
			guard let response = HTTPURLResponse(
				url: $0.url ?? URL(string: "https://example.com")!,
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			) else {
				throw Unimplemented()
			}
			return (data, response)
		}
	}
}
