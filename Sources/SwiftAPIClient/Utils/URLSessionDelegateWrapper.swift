import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

#if os(macOS) || os(iOS) || os(watchOS) || os(tvOS) || os(visionOS)
final class SessionDelegateProxy: NSObject {

	var configs: APIClient.Configs? {
		get {
			lock.lock()
			defer { lock.unlock() }
			return _configs
		}
		set {
			lock.lock()
			defer { lock.unlock() }
			_configs = newValue
		}
	}

	var originalDelegate: URLSessionDelegate? { configs?.urlSessionDelegate }

	private let lock = NSRecursiveLock()
	private var _configs: APIClient.Configs?

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
#else
final class SessionDelegateProxy: NSObject {

	var configs: APIClient.Configs?
    var originalDelegate: URLSessionDelegate? { configs?.urlSessionDelegate }
}
#endif

extension SessionDelegateProxy: URLSessionDelegate {

	static let shared = SessionDelegateProxy()
}

extension SessionDelegateProxy: URLSessionTaskDelegate {

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		willPerformHTTPRedirection response: HTTPURLResponse,
		newRequest request: URLRequest,
		completionHandler: @escaping (URLRequest?) -> Void
	) {
		switch configs?.redirectBehaviour ?? .follow {
		case .follow:
			completionHandler(request)
		case .doNotFollow:
			completionHandler(nil)
		case let .modify(modifier):
			completionHandler(modifier(request, response))
		}
	}

	func urlSession(
		_ session: URLSession,
		task: URLSessionTask,
		didSendBodyData bytesSent: Int64,
		totalBytesSent: Int64,
		totalBytesExpectedToSend: Int64
	) {
		configs?.uploadTracker(totalBytesSent, totalBytesExpectedToSend)
	}
}

#if canImport(UIKit)
import UIKit

extension SessionDelegateProxy {

	func urlSessionDidFinishEvents(
		forBackgroundURLSession session: URLSession
	) {}
}
#endif

extension SessionDelegateProxy: URLSessionDataDelegate {}

extension SessionDelegateProxy: URLSessionDownloadDelegate {

	func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
		(originalDelegate as? URLSessionDownloadDelegate)?
			.urlSession(session, downloadTask: downloadTask, didFinishDownloadingTo: location)
	}

	func urlSession(
		_ session: URLSession,
		downloadTask: URLSessionDownloadTask,
		didWriteData bytesWritten: Int64,
		totalBytesWritten: Int64,
		totalBytesExpectedToWrite: Int64
	) {
		configs?.downloadTracker(totalBytesWritten, totalBytesExpectedToWrite)
	}
}

extension SessionDelegateProxy: URLSessionStreamDelegate {}

extension SessionDelegateProxy: URLSessionWebSocketDelegate {}
