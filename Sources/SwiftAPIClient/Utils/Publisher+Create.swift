#if canImport(Combine)
import Combine
import Foundation

extension Publishers {

	struct Create<Output, Failure: Error>: Publisher {

		typealias Events = (
			@escaping (Output) -> Void,
			@escaping (Subscribers.Completion<Failure>) -> Void,
			@escaping (@escaping () -> Void) -> Void
		) -> Failure?

		let events: Events

		init(events: @escaping Events) {
			self.events = events
		}

		func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
			let subscription = CreateSubscription(create: self, subscriber: subscriber)
			subscriber.receive(subscription: subscription)
			subscription.start()
		}

		private final actor CreateSubscription<S: Subscriber>: Subscription where Failure == S.Failure, Output == S.Input {

			var subscriber: S?
			let create: Publishers.Create<Output, Failure>
			private var onCancel: [() -> Void] = []

			init(
				create: Publishers.Create<Output, Failure>,
				subscriber: S
			) {
				self.subscriber = subscriber
				self.create = create
			}

			nonisolated func start() {
				let failure = create.events(
					{ [weak self] output in
						guard let self else { return }
						Task {
							_ = await self.subscriber?.receive(output)
						}
					},
					{ [weak self] completion in
						guard let self else { return }
						Task {
							await self.subscriber?.receive(completion: completion)
							await self._cancel()
						}
					},
					{ [weak self] onCancel in
						guard let self else { return }
						Task {
							await self.onCancel(onCancel)
						}
					}
				)
				if let failure, !(failure is Never) {
					Task {
						await subscriber?.receive(completion: .failure(failure))
						await _cancel()
					}
				}
			}

			nonisolated func request(_: Subscribers.Demand) {}

			nonisolated func cancel() {
				Task {
					await self._cancel()
				}
			}

			private func onCancel(_ block: @escaping () -> Void) {
				onCancel.append(block)
			}

			private func _cancel() {
				subscriber = nil
				onCancel.forEach { $0() }
			}
		}
	}
}

extension Publishers.Create where Failure == Never {

	init(
		events: @escaping (
			@escaping (Output) -> Void,
			@escaping (Subscribers.Completion<Failure>) -> Void,
			@escaping (@escaping () -> Void) -> Void
		) -> Void
	) {
		self.events = { onOutput, onCompletion, cancellationHandler in
			events(onOutput, onCompletion, cancellationHandler)
			return nil
		}
	}
}

extension Publishers.Create where Failure == Error {

	init(
		events: @escaping (
			@escaping (Output) -> Void,
			@escaping (Subscribers.Completion<Failure>) -> Void,
			@escaping (@escaping () -> Void) -> Void
		) throws -> Void
	) {
		self.events = {
			do {
				try events($0, $1, $2)
				return nil
			} catch {
				return error
			}
		}
	}
}
#endif
