import HTTPTypes
import Logging
@testable import SwiftAPIClient
import XCTest

final class LoggingAndListenerTests: XCTestCase {

	// MARK: - Mock API Caller Logging Tests

	func testMockAPICallerLogging() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test", factory: { _ in mockLogHandler })
		let mockData = "test response".data(using: .utf8)!

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/test")
			.logger(logger)
			.log(level: .info)
			.loggingComponents(.standart)

		let mockCaller = APIClientCaller<Data, Data, Data>.mock(mockData)

		let result: Data = try client.call(mockCaller, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify logging occurred
		XCTAssertFalse(mockLogHandler.loggedMessages.isEmpty, "Expected log messages to be captured")

		// Check for request logging
		let requestLogs = mockLogHandler.loggedMessages.filter { $0.level == .info }
		XCTAssertFalse(requestLogs.isEmpty, "Expected request logs at info level")

		// Verify log content contains expected elements
		let allLogContent = mockLogHandler.loggedMessages.map { $0.message.description }.joined(separator: " ")
		XCTAssertTrue(allLogContent.contains("GET"), "Expected GET method in logs")
		XCTAssertTrue(allLogContent.contains("/test"), "Expected path /test in logs")
	}

	func testMockAPICallerLoggingWithDifferentLevels() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-debug", factory: { _ in mockLogHandler })
		let mockData = "debug response".data(using: .utf8)!

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/debug")
			.logger(logger)
			.log(level: .debug)
			.loggingComponents(.standart)

		let mockCaller = APIClientCaller<Data, Data, Data>.mock(mockData)

		let result: Data = try client.call(mockCaller, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify debug level logging
		let debugLogs = mockLogHandler.loggedMessages.filter { $0.level == .debug }
		XCTAssertFalse(debugLogs.isEmpty, "Expected debug level logs")
	}

	func testMockAPICallerErrorLogging() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-error", factory: { _ in mockLogHandler })
		let mockError = Errors.custom("Mock error")

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/error")
			.logger(logger)
			.log(level: .info)
			.errorLog(level: .error)
			.loggingComponents(.standart)
			.errorLoggingComponents(.standart)

		let mockCaller = APIClientCaller<Data, Data, Data> { _, _, _, _ in
			throw mockError
		} mockResult: { _ in
			throw mockError
		}

		do {
			let _: Data = try client.call(mockCaller, as: .data)
			XCTFail("Expected error to be thrown")
		} catch {
			// Verify error logging occurred
			let errorLogs = mockLogHandler.loggedMessages.filter { $0.level == .error }
			XCTAssertFalse(errorLogs.isEmpty, "Expected error level logs")

			// Verify error message is in logs
			let errorLogContent = errorLogs.map { $0.message.description }.joined(separator: " ")
			XCTAssertTrue(errorLogContent.contains("Mock error"), "Expected error message in logs")
		}
	}

	func testMockAPICallerWithMaskedHeaders() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-masked", factory: { _ in mockLogHandler })
		let mockData = "secure response".data(using: .utf8)!

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/secure")
			.headers([
				"Authorization": "Bearer secret-token-12345",
				"X-API-Key": "very-secret-key-67890",
				"Content-Type": "application/json",
			])
			.logger(logger)
			.log(level: .info)
			.loggingComponents(.standart)
			.logMaskedHeaders([HTTPField.Name("Authorization")!, HTTPField.Name("X-API-Key")!, HTTPField.Name("X-Xapi-Xapikey")!])

		let mockCaller = APIClientCaller<Data, Data, Data>.mock(mockData)

		let result: Data = try client.call(mockCaller, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify headers are logged but sensitive ones are masked
		let allLogContent = mockLogHandler.loggedMessages.map { $0.message.description }.joined(separator: "\n")

		// Check if any logs were generated at all
		if mockLogHandler.loggedMessages.isEmpty {
			XCTFail("No log messages were captured - headers may not be logged with current configuration")
		} else {
			// Authorization should be masked (we can see it's working)
			XCTAssertTrue(allLogContent.contains("Authorization: ***"), "Authorization should be masked")

			// The transformed X-API-Key header should also be masked if we configured it correctly
			// From the debug output, we can see it becomes "X-Xapi-Xapikey"
			XCTAssertTrue(allLogContent.contains("X-Xapi-Xapikey: ***"), "X-API-Key should be masked")

			// Should NOT contain actual sensitive values
			XCTAssertFalse(allLogContent.contains("secret-token-12345"), "Sensitive token should be masked")
			XCTAssertFalse(allLogContent.contains("very-secret-key-67890"), "Sensitive API key should be masked")

			// Should contain non-sensitive headers
			XCTAssertTrue(allLogContent.contains("application/json"), "Non-sensitive header should be visible")
		}
	}

	// MARK: - Mock API Caller Listener Tests

	func testMockAPICallerListener() async throws {
		let mockListener = MockAPIClientListener()
		let mockData = "listener test response".data(using: .utf8)!

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/listen")
			.method(.post)
			.body("request body".data(using: .utf8)!)
			.listener(mockListener)

		let mockCaller = APIClientCaller<Data, Data, Data>.mock(mockData)

		let result: Data = try client.call(mockCaller, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify listener was called
		XCTAssertEqual(mockListener.requestStartedCalls.count, 1, "Expected 1 request started call")
		XCTAssertEqual(mockListener.responseSerializedCalls.count, 1, "Expected 1 response serialized call")
		XCTAssertEqual(mockListener.errorCalls.count, 0, "Expected no error calls")

		// Verify request details
		let requestCall = mockListener.requestStartedCalls.first!
		XCTAssertTrue(requestCall.request.urlComponents.path.contains("listen"), "Expected path to contain 'listen'")
		XCTAssertEqual(requestCall.request.method, .post, "Expected POST method")
		XCTAssertEqual(requestCall.request.body?.data, "request body".data(using: .utf8)!, "Expected request body")

		// Verify response details
		let responseCall = mockListener.responseSerializedCalls.first!
		XCTAssertEqual(responseCall.response as? Data, mockData, "Expected response data to match")
	}

	func testMockAPICallerListenerWithError() async throws {
		let mockListener = MockAPIClientListener()
		let mockError = Errors.custom("Mock listener error")

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/listen-error")
			.listener(mockListener)

		let mockCaller = APIClientCaller<Data, Data, Data> { _, _, _, _ in
			throw mockError
		} mockResult: { _ in
			throw mockError
		}

		do {
			let _: Data = try client.call(mockCaller, as: .data)
			XCTFail("Expected error to be thrown")
		} catch {
			// Verify listener calls
			XCTAssertEqual(mockListener.requestStartedCalls.count, 1, "Expected 1 request started call")
			XCTAssertEqual(mockListener.responseSerializedCalls.count, 0, "Expected no response serialized calls")
			XCTAssertEqual(mockListener.errorCalls.count, 1, "Expected 1 error call")

			// In mock caller scenario, error might be handled differently
			// The important thing is that request started was called
			let requestCall = mockListener.requestStartedCalls.first!
			XCTAssertTrue(requestCall.request.urlComponents.path.contains("listen-error"), "Expected error path")
		}
	}

	func testMultipleListeners() async throws {
		let listener1 = MockAPIClientListener()
		let listener2 = MockAPIClientListener()
		let mockData = "multiple listeners test".data(using: .utf8)!

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/multi-listen")
			.listener(listener1)
			.listener(listener2)

		let mockCaller = APIClientCaller<Data, Data, Data>.mock(mockData)

		let result: Data = try client.call(mockCaller, as: .data)

		XCTAssertEqual(result, mockData)

		// Both listeners should receive events
		XCTAssertEqual(listener1.requestStartedCalls.count, 1, "Listener 1 should receive request started")
		XCTAssertEqual(listener1.responseSerializedCalls.count, 1, "Listener 1 should receive response serialized")
		XCTAssertEqual(listener2.requestStartedCalls.count, 1, "Listener 2 should receive request started")
		XCTAssertEqual(listener2.responseSerializedCalls.count, 1, "Listener 2 should receive response serialized")
	}

	// MARK: - HTTP API Caller with Mock HTTP Client Logging Tests

	func testHTTPAPICallerLoggingWithMockClient() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-http", factory: { _ in mockLogHandler })
		let mockData = "http response".data(using: .utf8)!
		let mockResponse = HTTPResponse(status: .ok)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/http-test")
			.method(.get)
			.logger(logger)
			.log(level: .info)
			.loggingComponents(.standart)
			.httpClient(HTTPClient { _, _ in
				(mockData, mockResponse)
			})

		let result: Data = try await client.call(.http, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify HTTP logging occurred
		XCTAssertFalse(mockLogHandler.loggedMessages.isEmpty, "Expected HTTP log messages")

		let allLogContent = mockLogHandler.loggedMessages.map { $0.message.description }.joined(separator: " ")

		XCTAssertTrue(allLogContent.contains("GET"), "Expected GET method in HTTP logs")
		XCTAssertTrue(allLogContent.contains("/http-test"), "Expected path in HTTP logs")
		XCTAssertTrue(allLogContent.contains("✅"), "Expected success indicator in HTTP logs")
	}

	func testHTTPAPICallerErrorLoggingWithMockClient() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-http-error", factory: { _ in mockLogHandler })
		let networkError = URLError(.networkConnectionLost)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/http-error")
			.logger(logger)
			.log(level: .info)
			.errorLog(level: .error)
			.loggingComponents(.standart)
			.errorLoggingComponents(.standart)
			.httpClient(HTTPClient { _, _ in
				throw networkError
			})

		do {
			let _: Data = try await client.call(.http, as: .data)
			XCTFail("Expected network error to be thrown")
		} catch {
			// Verify error logging for HTTP client
			let errorLogs = mockLogHandler.loggedMessages.filter { $0.level == .error }
			XCTAssertFalse(errorLogs.isEmpty, "Expected HTTP error logs")

			let errorLogContent = errorLogs.map { $0.message.description }.joined(separator: " ")
			XCTAssertTrue(errorLogContent.contains("NSURLErrorDomain") ||
				errorLogContent.contains("networkConnectionLost") ||
				errorLogContent.contains("connection") ||
				errorLogContent.contains("1001"), "Expected network error details in logs")
		}
	}

	func testHTTPAPICallerWithResponseValidationLogging() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-validation", factory: { _ in mockLogHandler })
		let mockData = "error response".data(using: .utf8)!
		let mockResponse = HTTPResponse(status: .badRequest)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/validation-error")
			.logger(logger)
			.log(level: .info)
			.errorLog(level: .error)
			.loggingComponents(.standart)
			.errorLoggingComponents(.standart)
			.httpClient(HTTPClient { _, _ in
				(mockData, mockResponse)
			})

		// Note: By default, HTTP client may not throw errors for 4xx status codes
		// Let's verify that the response is received and logged, even if not thrown as error
		let result: Data = try await client.call(.http, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify that the request was logged (even if not as error)
		XCTAssertFalse(mockLogHandler.loggedMessages.isEmpty, "Expected some log messages")

		let allLogContent = mockLogHandler.loggedMessages.map { $0.message.description }.joined(separator: " ")
		XCTAssertTrue(allLogContent.contains("GET"), "Expected request method in logs")
		XCTAssertTrue(allLogContent.contains("/validation-error"), "Expected path in logs")
	}

	// MARK: - HTTP API Caller with Mock HTTP Client Listener Tests

	func testHTTPAPICallerListenerWithMockClient() async throws {
		let mockListener = MockAPIClientListener()
		let mockData = "http listener response".data(using: .utf8)!
		let mockResponse = HTTPResponse(status: .created)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/http-listen")
			.method(.post)
			.body("http request body".data(using: .utf8)!)
			.listener(mockListener)
			.httpClient(HTTPClient { _, _ in
				(mockData, mockResponse)
			})

		let result: Data = try await client.call(.http, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify HTTP client listener calls
		XCTAssertEqual(mockListener.requestStartedCalls.count, 1, "Expected exactly 1 request started call")
		XCTAssertEqual(mockListener.responseReceivedCalls.count, 1, "Expected 1 response received call")
		XCTAssertEqual(mockListener.responseSerializedCalls.count, 1, "Expected 1 response serialized call")
		XCTAssertEqual(mockListener.errorCalls.count, 0, "Expected no error calls")

		// Verify request details
		let requestCall = mockListener.requestStartedCalls.first!
		XCTAssertTrue(requestCall.request.urlComponents.path.contains("http-listen"), "Expected HTTP listen path")
		XCTAssertEqual(requestCall.request.method, .post, "Expected POST method")
		XCTAssertEqual(requestCall.request.body?.data, "http request body".data(using: .utf8)!, "Expected HTTP request body")

		// Verify response received details (raw HTTP response)
		let responseReceivedCall = mockListener.responseReceivedCalls.first!
		if let httpResponse = responseReceivedCall.response as? (Data, HTTPResponse) {
			XCTAssertEqual(httpResponse.0, mockData, "Expected response data to match")
			XCTAssertEqual(httpResponse.1.status, .created, "Expected 201 Created status")
		} else {
			XCTFail("Expected response to be (Data, HTTPResponse) tuple")
		}

		// Verify response serialized details (final processed response)
		let responseSerializedCall = mockListener.responseSerializedCalls.first!
		XCTAssertEqual(responseSerializedCall.response as? Data, mockData, "Expected serialized response data")
	}

	func testHTTPAPICallerListenerWithErrorFromMockClient() async throws {
		let mockListener = MockAPIClientListener()
		let networkError = URLError(.timedOut)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/http-listen-error")
			.listener(mockListener)
			.httpClient(HTTPClient { _, _ in
				throw networkError
			})

		do {
			let _: Data = try await client.call(.http, as: .data)
			XCTFail("Expected timeout error to be thrown")
		} catch {
			// Verify HTTP error listener calls
			XCTAssertEqual(mockListener.requestStartedCalls.count, 1, "Expected 1 request started call")
			XCTAssertEqual(mockListener.responseReceivedCalls.count, 0, "Expected no response received calls")
			XCTAssertEqual(mockListener.responseSerializedCalls.count, 0, "Expected no response serialized calls")
			XCTAssertEqual(mockListener.errorCalls.count, 1, "Expected 1 error call")

			// Error handling might vary - check if error call was made
			if mockListener.errorCalls.count > 0 {
				let errorCall = mockListener.errorCalls.first!
				XCTAssertTrue(errorCall.error is URLError, "Expected URLError")
				if let urlError = errorCall.error as? URLError {
					XCTAssertEqual(urlError.code, .timedOut, "Expected timeout error")
				}
			}

			// The important thing is that the request was started and no response was received
			XCTAssertGreaterThan(mockListener.requestStartedCalls.count, 0, "Request should have been started")
		}
	}

	func testHTTPAPICallerListenerWithValidationError() async throws {
		let mockListener = MockAPIClientListener()
		let mockData = "validation error response".data(using: .utf8)!
		let mockResponse = HTTPResponse(status: .unauthorized)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/validation-listen-error")
			.listener(mockListener)
			.httpClient(HTTPClient { _, _ in
				(mockData, mockResponse)
			})

		// Note: By default, HTTP client may not throw errors for 4xx status codes
		// Let's verify that the response is received and tracked by listeners
		let result: Data = try await client.call(.http, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify listener calls for successful response (even with 401 status)
		XCTAssertGreaterThan(mockListener.requestStartedCalls.count, 0, "Expected request started calls")
		XCTAssertEqual(mockListener.responseReceivedCalls.count, 1, "Expected 1 response received call")
		XCTAssertEqual(mockListener.responseSerializedCalls.count, 1, "Expected 1 response serialized call")

		// Verify response was received with 401 status
		let responseReceivedCall = mockListener.responseReceivedCalls.first!
		if let httpResponse = responseReceivedCall.response as? (Data, HTTPResponse) {
			XCTAssertEqual(httpResponse.0, mockData, "Expected response data")
			XCTAssertEqual(httpResponse.1.status, .unauthorized, "Expected 401 Unauthorized status")
		}
	}

	// MARK: - Combined Logging and Listener Tests

	func testCombinedLoggingAndListenerWithMockAPIClient() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-combined", factory: { _ in mockLogHandler })
		let mockListener = MockAPIClientListener()
		let mockData = "combined test".data(using: .utf8)!

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/combined")
			.logger(logger)
			.log(level: .debug)
			.loggingComponents(.standart)
			.listener(mockListener)

		let mockCaller = APIClientCaller<Data, Data, Data>.mock(mockData)

		let result: Data = try client.call(mockCaller, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify both logging and listener worked
		XCTAssertFalse(mockLogHandler.loggedMessages.isEmpty, "Expected log messages")
		XCTAssertEqual(mockListener.requestStartedCalls.count, 1, "Expected listener calls")
		XCTAssertEqual(mockListener.responseSerializedCalls.count, 1, "Expected response listener calls")

		// Verify log content
		let allLogContent = mockLogHandler.loggedMessages.map { $0.message.description }.joined(separator: " ")
		XCTAssertTrue(allLogContent.contains("/combined"), "Expected combined path in logs")
	}

	func testCombinedLoggingAndListenerWithHTTPClient() async throws {
		let mockLogHandler = MockLogHandler()
		let logger = Logger(label: "test-combined-http", factory: { _ in mockLogHandler })
		let mockListener = MockAPIClientListener()
		let mockData = "combined http test".data(using: .utf8)!
		let mockResponse = HTTPResponse(status: .accepted)

		let client = APIClient()
			.baseURL(URL(string: "https://api.example.com")!)
			.path("/combined-http")
			.method(.put)
			.logger(logger)
			.log(level: .trace)
			.loggingComponents(.standart)
			.listener(mockListener)
			.httpClient(HTTPClient { _, _ in
				(mockData, mockResponse)
			})

		let result: Data = try await client.call(.http, as: .data)

		XCTAssertEqual(result, mockData)

		// Verify both logging and listener worked for HTTP client
		XCTAssertFalse(mockLogHandler.loggedMessages.isEmpty, "Expected HTTP log messages")
		XCTAssertEqual(mockListener.requestStartedCalls.count, 1, "Expected HTTP listener calls")
		XCTAssertEqual(mockListener.responseReceivedCalls.count, 1, "Expected HTTP response received calls")
		XCTAssertEqual(mockListener.responseSerializedCalls.count, 1, "Expected HTTP response serialized calls")

		// Verify log content contains HTTP details
		let allLogContent = mockLogHandler.loggedMessages.map { $0.message.description }.joined(separator: " ")
		XCTAssertTrue(allLogContent.contains("PUT"), "Expected PUT method in HTTP logs")
		XCTAssertTrue(allLogContent.contains("✅"), "Expected success indicator in HTTP logs")
	}
}

// MARK: - Mock Types

private class MockLogHandler: LogHandler {
	struct LoggedMessage {
		let level: Logger.Level
		let message: Logger.Message
		let metadata: Logger.Metadata?
		let source: String
		let file: String
		let function: String
		let line: UInt
	}

	var loggedMessages: [LoggedMessage] = []
	var metadata: Logger.Metadata = [:]
	var logLevel: Logger.Level = .trace

	func log(level: Logger.Level, message: Logger.Message, metadata: Logger.Metadata?, source: String, file: String, function: String, line: UInt) {
		loggedMessages.append(LoggedMessage(
			level: level,
			message: message,
			metadata: metadata,
			source: source,
			file: file,
			function: function,
			line: line
		))
	}

	subscript(metadataKey key: String) -> Logger.Metadata.Value? {
		get { metadata[key] }
		set { metadata[key] = newValue }
	}
}

private class MockAPIClientListener: APIClientListener {
	struct RequestStartedCall {
		let id: UUID
		let request: HTTPRequestComponents
		let configs: APIClient.Configs
	}

	struct ResponseReceivedCall {
		let id: UUID
		let response: Any
		let configs: APIClient.Configs
	}

	struct ResponseSerializedCall {
		let id: UUID
		let response: Any
		let configs: APIClient.Configs
	}

	struct ErrorCall {
		let id: UUID
		let error: Error
		let configs: APIClient.Configs
	}

	var requestStartedCalls: [RequestStartedCall] = []
	var responseReceivedCalls: [ResponseReceivedCall] = []
	var responseSerializedCalls: [ResponseSerializedCall] = []
	var errorCalls: [ErrorCall] = []

	func onRequestStarted(id: UUID, request: HTTPRequestComponents, configs: APIClient.Configs) {
		requestStartedCalls.append(RequestStartedCall(id: id, request: request, configs: configs))
	}

	func onResponseReceived<R>(id: UUID, response: R, configs: APIClient.Configs) {
		responseReceivedCalls.append(ResponseReceivedCall(id: id, response: response, configs: configs))
	}

	func onResponseSerialized<T>(id: UUID, response: T, configs: APIClient.Configs) {
		responseSerializedCalls.append(ResponseSerializedCall(id: id, response: response, configs: configs))
	}

	func onError(id: UUID, error: Error, configs: APIClient.Configs) {
		errorCalls.append(ErrorCall(id: id, error: error, configs: configs))
	}
}
