import Foundation

#if !canImport(FoundationNetworking)

final class SessionDelegateProxy: NSObject, URLSessionDelegate {

	static let shared = SessionDelegateProxy()

	var originalDelegate: URLSessionDelegate? { configs?.urlSessionDelegate }
	var configs: APIClient.Configs?

	override func responds(to aSelector: Selector!) -> Bool {
		if super.responds(to: aSelector) {
			return true
		}
		return originalDelegate?.responds(to: aSelector) ?? false
	}

	override func forwardingTarget(for aSelector: Selector!) -> Any? {
		if originalDelegate?.responds(to: aSelector) == true {
			return originalDelegate
		}
		return super.forwardingTarget(for: aSelector)
	}
}

extension SessionDelegateProxy: URLSessionTaskDelegate {

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		willPerformHTTPRedirection response: HTTPURLResponse,
		newRequest request: URLRequest,
		completionHandler: @escaping (URLRequest?) -> Void
	) {
		guard let configs else {
			(originalDelegate as? URLSessionTaskDelegate)?
				.urlSession?(
					session,
					task: task,
					willPerformHTTPRedirection: response,
					newRequest: request,
					completionHandler: completionHandler
				)
			return
		}
		switch configs.redirectBehaviour {
		case .follow:
			completionHandler(request)
		case .doNotFollow:
			completionHandler(nil)
		case let .modify(modifier):
			completionHandler(modifier(request, response))
		}
	}
}

extension SessionDelegateProxy: URLSessionDataDelegate {}

extension SessionDelegateProxy: URLSessionDownloadDelegate {

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		(originalDelegate as? URLSessionDownloadDelegate)?
			.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
	}
}

extension SessionDelegateProxy: URLSessionStreamDelegate {}

extension SessionDelegateProxy: URLSessionWebSocketDelegate {}
#endif
