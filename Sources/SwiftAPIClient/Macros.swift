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
#endif

@propertyWrapper
public struct APIParameterWrapper<Value> {

    public var wrappedValue: Value

    public init(wrappedValue: Value) {
        self.wrappedValue = wrappedValue
    }
}

@API 
public struct API {

    public init(url: URL) {
        client = APIClient(baseURL: url)
    }

    @Path
    public struct Pet {

        @GET public func get(@Query status: Int, @Body body: Data) {}
    }
}

func test() async throws {
    let api = API(url: URL(string: "")!)
    
    try await api.pet.get(id: 0, status: 0, body: Data())
}

@resultBuilder
public enum APICallFakeBuilder {

    public static func buildBlock<T>() -> T {
        fatalError()
    }

    public static func buildBlock<T>(_ component: APIClient) -> T {
        fatalError()
    }
}
