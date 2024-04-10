@preconcurrency import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public extension APIClient.Configs {

	/// The closure that is called when the upload progress is updated.
	var uploadTracker: (_ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void {
		get { self[\.uploadTracker] ?? { _, _ in } }
		set { self[\.uploadTracker] = newValue }
	}
}

public extension APIClient {

	/// Observe the upload progress of the request.
	func trackUpload(_ action: @escaping (_ progress: Double) -> Void) -> Self {
		trackUpload { totalBytesSent, totalBytesExpectedToSend in
			guard totalBytesExpectedToSend > 0 else {
				action(1)
				return
			}
			action(Double(totalBytesSent) / Double(totalBytesExpectedToSend))
		}
	}

	/// Observe the upload progress of the request.
	func trackUpload(_ action: @escaping (_ totalBytesSent: Int64, _ totalBytesExpectedToSend: Int64) -> Void) -> Self {
		configs {
			let current = $0.uploadTracker
			$0.uploadTracker = { totalBytesSent, totalBytesExpectedToSend in
				current(totalBytesSent, totalBytesExpectedToSend)
				action(totalBytesSent, totalBytesExpectedToSend)
			}
		}
	}
}
