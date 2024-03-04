#if canImport(Combine)
import Combine
import Foundation

extension Publishers {

	struct Create<Output, Failure: Error>: Publisher {

		let events: (
			@escaping (Output) -> Void,
			@escaping (Subscribers.Completion<Failure>) -> Void
		) -> Void

		func receive<S: Subscriber>(subscriber: S) where Failure == S.Failure, Output == S.Input {
			let subscription = CreateSubscription(create: self, subscriber: subscriber)
			subscriber.receive(subscription: subscription)
			subscription.start()
		}

		private final class CreateSubscription<S: Subscriber>: Subscription where Failure == S.Failure, Output == S.Input {

			var subscriber: S?
			let create: Publishers.Create<Output, Failure>

			init(
				create: Publishers.Create<Output, Failure>,
				subscriber: S
			) {
				self.subscriber = subscriber
				self.create = create
			}

			func start() {
				create.events(
					{ [weak self] output in
						guard let self else { return }
						_ = self.subscriber?.receive(output)
					},
					{ [weak self] completion in
						guard let self else { return }
						self.subscriber?.receive(completion: completion)
						self.cancel()
					}
				)
			}

			func request(_: Subscribers.Demand) {}

			func cancel() {
				subscriber = nil
			}
		}
	}
}
#endif
