#if canImport(Combine)
import Combine
import Foundation

public extension NetworkClientCaller where Result == AnyPublisher<Value, Error>, Response == Data {

	static var httpPublisher: NetworkClientCaller {
		NetworkClientCaller<Response, Value, AsyncValue<Value>>.http.map { value in
			Publishers.Task {
				try await value()
			}
			.eraseToAnyPublisher()
		}
	}
}
#endif
