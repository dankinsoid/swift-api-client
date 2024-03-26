#if swift(>=5.9)
import Foundation
import HTTPTypes

@attached(peer, names: arbitrary)
public macro Call(
	_ method: HTTPRequest.Method,
	_ path: String...
) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

@attached(peer, names: arbitrary)
public macro GET(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")
@attached(peer, names: arbitrary)
public macro POST(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")
@attached(peer, names: arbitrary)
public macro PUT(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")
@attached(peer, names: arbitrary)
public macro DELETE(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")
@attached(peer, names: arbitrary)
public macro PATCH(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

@attached(peer, names: arbitrary)
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro Path(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientPathMacro")

@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro API() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientPathMacro")

@freestanding(declaration, names: arbitrary)
public macro GET<T>(_ type: T.Type = T.self) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")
@freestanding(declaration, names: arbitrary)
public macro GET() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")

@freestanding(declaration, names: arbitrary)
public macro POST<T>(_ type: T.Type = T.self) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")
@freestanding(declaration, names: arbitrary)
public macro POST() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")

@freestanding(declaration, names: arbitrary)
public macro PUT<T>(_ type: T.Type = T.self) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")
@freestanding(declaration, names: arbitrary)
public macro PUT() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")

@freestanding(declaration, names: arbitrary)
public macro DELETE<T>(_ type: T.Type = T.self) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")
@freestanding(declaration, names: arbitrary)
public macro DELETE() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")

@freestanding(declaration, names: arbitrary)
public macro PATCH<T>(_ type: T.Type = T.self) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")
@freestanding(declaration, names: arbitrary)
public macro PATCH() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientFreestandingMacro")

@propertyWrapper
public struct _APIParameterWrapper<Value> {

	public var wrappedValue: Value

	public init(wrappedValue: Value) {
		self.wrappedValue = wrappedValue
	}
}

@resultBuilder
public enum APICallFakeBuilder {

	public static func buildBlock<T>() -> T {
		fatalError()
	}

	public static func buildBlock<T>(_: APIClient) -> T {
		fatalError()
	}
}
#endif
