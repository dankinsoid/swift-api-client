import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

extension URLResponse {

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
