import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLRequest {

	init?(request: HTTPRequest, configs: APIClient.Configs) {
		guard var urlRequest = URLRequest(httpRequest: request) else {
			return nil
		}
		urlRequest.timeoutInterval = configs.timeoutInterval
		self = urlRequest
	}
}
