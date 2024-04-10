import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import HTTPTypes

extension URLResponse {

	var http: HTTPResponse {
		if let response = (self as? HTTPURLResponse)?.httpResponse {
			return response
		}
		return HTTPResponse(status: .accepted)
	}
}
