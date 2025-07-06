import Foundation

/// A type-erasing wrapper for any `AsyncSequence`.
@available(*, deprecated, message: "This type is deprecated and will be removed in a future version")
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
			let box = Box(sequence.makeAsyncIterator())
			return AsyncIterator {
				try await box.iterator.next()
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
		
		public init(next: @escaping @Sendable () async throws -> Element?) {
			_next = next
		}
		
		public mutating func next() async throws -> Element? {
			try await _next()
		}
	}

	private final class Box<I: AsyncIteratorProtocol> where I.Element == Element {
		var iterator: I
		init(_ iterator: I) {
			self.iterator = iterator
		}
	}
}

public extension AsyncSequence {

	/// Erases the type of this sequence and returns an `AnyAsyncSequence` instance.
	/// - Returns: An instance of `AnyAsyncSequence` wrapping the original sequence.
	@available(*, deprecated, message: "This method is deprecated and will be removed in a future version")
	@_disfavoredOverload
	func eraseToAnyAsyncSequence() -> AnyAsyncSequence<Element> {
		AnyAsyncSequence(self)
	}
}
