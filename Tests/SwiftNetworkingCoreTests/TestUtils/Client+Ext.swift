import Foundation
import SwiftNetworkingCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension NetworkClient {

	func request() throws -> URLRequest {
		try withRequest { request, _ in request }
	}

	func configs() -> Configs {
		withConfigs { $0 }
	}
}
