import Foundation
import SwiftNetworkingCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension NetworkClient {

	static var test: NetworkClient {
		NetworkClient(baseURL: URL(string: "https://example.com")!)
	}

	func configs() -> Configs {
		withConfigs { $0 }
	}
}
