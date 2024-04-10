@preconcurrency import Foundation
import SwiftAPIClient
#if canImport(FoundationNetworking)
@preconcurrency import FoundationNetworking
#endif

extension APIClient {

	static var test: APIClient {
		APIClient(baseURL: URL(string: "https://example.com")!)
	}

	func configs() -> Configs {
		withConfigs { $0 }
	}
}
