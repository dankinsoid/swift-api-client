import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLResponse {

	var isStatusCodeValid: Bool {
		if let response = self as? HTTPURLResponse {
			return response.statusCode >= 200 && response.statusCode < 300
		}
		return false
	}

	var http: HTTPURLResponse? {
		if let response = self as? HTTPURLResponse {
			return response
		}
		return url.flatMap {
			HTTPURLResponse(
				url: $0,
				statusCode: 200,
				httpVersion: nil,
				headerFields: nil
			)
		}
	}
}
