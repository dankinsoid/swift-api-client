#if canImport(Combine)
import Combine
import Foundation
import HTTPTypes

public extension APIClientCaller where Result == AnyPublisher<Value, Error>, Response == Data {

	static var httpPublisher: APIClientCaller {
		APIClientCaller<Response, Value, AnyPublisher<(Value, HTTPResponse), Error>>
			.httpResponsePublisher
			.map { publisher in
				publisher.map(\.0)
					.eraseToAnyPublisher()
			}
	}
}

public extension APIClientCaller where Result == AnyPublisher<(Value, HTTPResponse), Error>, Response == Data {

	static var httpResponsePublisher: APIClientCaller {
		APIClientCaller<Response, Value, AsyncThrowingValue<(Value, HTTPResponse)>>.httpResponse.map { value in
			Publishers.Run {
				try await value()
			}
			.eraseToAnyPublisher()
		}
	}
}
#endif
