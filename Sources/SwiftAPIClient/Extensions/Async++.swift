import Foundation

func completionToThrowsAsync<T>(
	_ body: @escaping (CheckedContinuation<T, Error>, CheckedContinuationCancellationHandler) -> Void
) async throws -> T {
	let handler = CheckedContinuationCancellationHandler()
	return try await withTaskCancellationHandler {
		try Task.checkCancellation()
		return try await withCheckedThrowingContinuation { continuation in
			body(continuation, handler)
		}
	} onCancel: {
		handler.handler.cancel()
	}
}

struct CheckedContinuationCancellationHandler {

	fileprivate let handler = TransactionCancelHandler()

	func onCancel(_ body: @escaping () -> Void) {
		handler.setOnCancel(body)
	}
}

/// There is currently no good way to asynchronously cancel an object that is initiated inside the `body` closure of `with*Continuation`.
/// As a workaround we use `TransactionCancelHandler` which will take care of the race between instantiation of `Transaction`
/// in the `body` closure and cancelation from the `onCancel` closure  of `withTaskCancellationHandler`.
@available(macOS 10.15, iOS 13.0, watchOS 6.0, tvOS 13.0, *)
private actor TransactionCancelHandler {

	private enum State {

		case initialised
		case cancelled
	}

	private var state: State = .initialised
	private var onCancel: () -> Void

	init() {
		onCancel = {}
	}

	private func _cancel() {
		switch state {
		case .cancelled:
			break
		case .initialised:
			state = .cancelled
			onCancel()
			onCancel = {}
		}
	}

	private func _setOnCancel(_ onCancel: @escaping () -> Void) {
		self.onCancel = onCancel
	}

	nonisolated func setOnCancel(_ onCancel: @escaping () -> Void) {
		Task {
			await self._setOnCancel(onCancel)
		}
	}

	nonisolated func cancel() {
		Task {
			await self._cancel()
		}
	}
}
