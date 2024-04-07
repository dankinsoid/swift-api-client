#if canImport(Combine)
import Combine
import Foundation

public extension APIClientCaller where Result == AnyPublisher<Value, Error>, Response == Data {

	static var httpPublisher: APIClientCaller {
		APIClientCaller<Response, Value, AsyncThrowingValue<Value>>.http.map { value in
			Publishers.Run {
				try await value()
			}
			.eraseToAnyPublisher()
		}
	}
}
#endif
