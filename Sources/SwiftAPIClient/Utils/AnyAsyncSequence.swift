@preconcurrency import Foundation

/// A type-erasing wrapper for any `AsyncSequence`.
public struct AnyAsyncSequence<Element>: AsyncSequence {

	private var _makeAsyncIterator: () -> AsyncIterator

	/// Initializes a new instance with the provided iterator-making closure.
	/// - Parameter makeAsyncIterator: A closure that returns an `AsyncIterator`.
	public init(makeAsyncIterator: @escaping () -> AsyncIterator) {
		_makeAsyncIterator = makeAsyncIterator
	}

	/// Initializes a new instance by wrapping an existing `AsyncSequence`.
	/// - Parameter sequence: An `AsyncSequence` whose elements to iterate over.
	public init<S: AsyncSequence>(_ sequence: S) where S.Element == Element {
		self.init {
			var iterator = sequence.makeAsyncIterator()
			return AsyncIterator {
				try await iterator.next()
			}
		}
	}

	/// Creates an iterator for the underlying async sequence.
	public func makeAsyncIterator() -> AsyncIterator {
		_makeAsyncIterator()
	}

	/// The iterator for `AnyAsyncSequence`.
	public struct AsyncIterator: AsyncIteratorProtocol {

		private var _next: () async throws -> Element?

		public init(next: @escaping () async throws -> Element?) {
			_next = next
		}

		public mutating func next() async throws -> Element? {
			try await _next()
		}
	}
}

public extension AsyncSequence {

	/// Erases the type of this sequence and returns an `AnyAsyncSequence` instance.
	/// - Returns: An instance of `AnyAsyncSequence` wrapping the original sequence.
	func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
		AnyAsyncSequence(self)
	}
}
