#if canImport(Combine)
import Combine
import Foundation

public extension Publishers {

	struct Task<Output, Failure: Error>: Publisher {

		fileprivate let task: ((Result<Output, Failure>) -> Void) async -> Void

		init(_ task: @escaping ((Result<Output, Failure>) -> Void) async -> Void) {
			self.task = task
		}

		public func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
			Publishers.Create<Output, Failure> { onOutput, onCompletion in
				_Concurrency.Task {
					await task {
						switch $0 {
						case let .success(output):
							onOutput(output)
							onCompletion(.finished)

						case let .failure(error):
							if error is CancellationError {
								onCompletion(.finished)
							} else {
								onCompletion(.failure(error))
							}
						}
					}
				}
			}
			.receive(subscriber: subscriber)
		}
	}
}

public extension Publishers.Task where Failure == Never {

	init(_ task: @escaping () async -> Output) {
		self.init { send in
			await send(.success(task()))
		}
	}

	init(_ task: @escaping ((Output) -> Void) async -> Void) {
		self.init { send in
			await task {
				send(.success($0))
			}
		}
	}
}

public extension Publishers.Task where Failure == Error {

	init(_ task: @escaping ((Output) -> Void) async throws -> Void) {
		self.init { send in
			do {
				try await task {
					send(.success($0))
				}
			} catch {
				send(.failure(error))
			}
		}
	}

	init(_ task: @escaping () async throws -> Output) {
		self.init { send in
			do {
				try await send(.success(task()))
			} catch {
				send(.failure(error))
			}
		}
	}
}
#endif
