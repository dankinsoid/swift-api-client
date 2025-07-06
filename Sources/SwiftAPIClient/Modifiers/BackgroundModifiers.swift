#if canImport(UIKit)
import UIKit

public extension APIClient {

	/// Execute the http request in the background task.
	///
	/// To know more about background task, see [Apple Documentation](https://developer.apple.com/documentation/backgroundtasks)
	func backgroundTask() -> Self {
		httpClientMiddleware(BackgroundTaskMiddleware())
	}

	/// Retry the http request when enter foreground if it was failed in the background.
	func retryIfFailedInBackground() -> Self {
		httpClientMiddleware(RetryOnEnterForegroundMiddleware())
	}
}

private struct BackgroundTaskMiddleware: HTTPClientMiddleware {

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		let id = await UIApplication.shared.beginBackgroundTask(
			withName: "Background Task for \(request.url?.absoluteString ?? "")"
		)
		guard id != .invalid else {
			return try await next(request, configs)
		}
		do {
			let result = try await next(request, configs)
			await UIApplication.shared.endBackgroundTask(id)
			return result
		} catch {
			await UIApplication.shared.endBackgroundTask(id)
			throw error
		}
	}
}

private struct RetryOnEnterForegroundMiddleware: HTTPClientMiddleware {

	func execute<T>(
		request: HTTPRequestComponents,
		configs: APIClient.Configs,
		next: @escaping @Sendable (HTTPRequestComponents, APIClient.Configs) async throws -> (T, HTTPResponse)
	) async throws -> (T, HTTPResponse) {
		func makeRequest() async throws -> (T, HTTPResponse) {
			let wasInBackground = WasInBackgroundService()
			var isInBackground = await UIApplication.shared.applicationState == .background
			if !isInBackground {
				await wasInBackground.start()
			}
			do {
				return try await next(request, configs)
			} catch {
				isInBackground = await UIApplication.shared.applicationState == .background
				if !isInBackground, await wasInBackground.wasInBackground {
					return try await makeRequest()
				}
				throw error
			}
		}
		return try await makeRequest()
	}
}

private final actor WasInBackgroundService {

	public private(set) var wasInBackground = false
	private var observer: NSObjectProtocol?

	public func start() async {
		observer = NotificationCenter.default.addObserver(
			forName: UIApplication.didEnterBackgroundNotification,
			object: nil,
			queue: nil
		) { [weak self] _ in
			guard let self else { return }
			Task {
				await self.setTrue()
			}
		}
	}

	public func reset() {
		wasInBackground = false
	}

	private func setTrue() {
		wasInBackground = true
	}
}
#endif
