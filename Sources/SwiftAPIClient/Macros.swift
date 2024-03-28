#if swift(>=5.9)
import Foundation
import HTTPTypes

/// A macro that generates an HTTP call to the API client.
///
/// - Parameters:
///   - method: The HTTP method to be used for the request.
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the function name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// Must be used with a function within a struct attributed with `@API` or `@Path` macro.
///
/// The function must have an empty body `{}` and return either a `Decodable` type, tuple, `String`, `Data`, or `Void`.
///
/// You can specify the body and query in two ways:
/// - `@Body` and `@Query` parameter attributes. These attributes add a parameter to the body or query with the same name as the parameter. If you specify two names, the second name will be used for the parameter name.
/// - Encodable or tuple parameters named `body` or `query`. These parameters will be encoded and used as body or query parameters as is.
///
/// Examples:
/// ```swift
/// @API
/// struct API {
///
///   /// GET /pets
///   @Call(.get)
///   func pets(@Query name: String? = nil) -> [Pets] {}
///
///   /// GET /users/{id}
///   @Call(.get, "/users/{id:Int}")
///   func getUser() -> User {}
/// }
/// ```
///
/// You can add custom APIClient modifiers such as `.header(_:)`, `.auth(enabled:)`, etc., in the function body using the `client` property.
/// ```swift
/// /// PUT /user
/// @Call(.put)
/// func user(_ body: User) {
///   client
///     .auth(enabled: true)
/// }
/// ```
/// - Warning: If you use swiftformat disable unusedArguments rule: `--disable unusedArguments` or `//swiftformat:disable:unusedArguments`
@attached(peer, names: arbitrary)
public macro Call(
	_ method: HTTPRequest.Method,
	_ path: String...
) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

/// A macro that generates an HTTP **GET** call to the API client.
///
/// - Parameters:
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the function name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// Must be used with a function within a struct attributed with `@API` or `@Path` macro.
///
/// The function must have an empty body `{}` and return either a `Decodable` type, tuple, `String`, `Data`, or `Void`.
///
/// You can specify the body and query in two ways:
/// - `@Body` and `@Query` parameter attributes. These attributes add a parameter to the body or query with the same name as the parameter. If you specify two names, the second name will be used for the parameter name.
/// - Encodable or tuple parameters named `body` or `query`. These parameters will be encoded and used as body or query parameters as is.
///
/// Examples:
/// ```swift
/// @API
/// struct API {
///
///   /// GET /pets
///   @GET
///   func pets(@Query name: String? = nil) -> [Pets] {}
///
///   /// GET /users/{id}
///   @GET("/users/{id:Int}")
///   func getUser() -> User {}
/// }
/// ```
///
/// You can add custom APIClient modifiers such as `.header(_:)`, `.auth(enabled:)`, etc., in the function body using the `client` property.
/// ```swift
/// /// PUT /user
/// @PUT
/// func user(_ body: User) {
///   client
///     .auth(enabled: true)
/// }
/// ```
/// - Warning: If you use swiftformat disable unusedArguments rule: `--disable unusedArguments` or `//swiftformat:disable:unusedArguments`
@attached(peer, names: arbitrary)
public macro GET(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

/// A macro that generates an HTTP **POST** call to the API client.
///
/// - Parameters:
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the function name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// Must be used with a function within a struct attributed with `@API` or `@Path` macro.
///
/// The function must have an empty body `{}` and return either a `Decodable` type, tuple, `String`, `Data`, or `Void`.
///
/// You can specify the body and query in two ways:
/// - `@Body` and `@Query` parameter attributes. These attributes add a parameter to the body or query with the same name as the parameter. If you specify two names, the second name will be used for the parameter name.
/// - Encodable or tuple parameters named `body` or `query`. These parameters will be encoded and used as body or query parameters as is.
///
/// Examples:
/// ```swift
/// @API
/// struct API {
///
///   /// GET /pets
///   @GET
///   func pets(@Query name: String? = nil) -> [Pets] {}
///
///   /// GET /users/{id}
///   @GET("/users/{id:Int}")
///   func getUser() -> User {}
/// }
/// ```
///
/// You can add custom APIClient modifiers such as `.header(_:)`, `.auth(enabled:)`, etc., in the function body using the `client` property.
/// ```swift
/// /// PUT /user
/// @PUT
/// func user(_ body: User) {
///   client
///     .auth(enabled: true)
/// }
/// ```
/// - Warning: If you use swiftformat disable unusedArguments rule: `--disable unusedArguments` or `//swiftformat:disable:unusedArguments`
@attached(peer, names: arbitrary)
public macro POST(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

/// A macro that generates an HTTP **PUT** call to the API client.
///
/// - Parameters:
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the function name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// Must be used with a function within a struct attributed with `@API` or `@Path` macro.
///
/// The function must have an empty body `{}` and return either a `Decodable` type, tuple, `String`, `Data`, or `Void`.
///
/// You can specify the body and query in two ways:
/// - `@Body` and `@Query` parameter attributes. These attributes add a parameter to the body or query with the same name as the parameter. If you specify two names, the second name will be used for the parameter name.
/// - Encodable or tuple parameters named `body` or `query`. These parameters will be encoded and used as body or query parameters as is.
///
/// Examples:
/// ```swift
/// @API
/// struct API {
///
///   /// GET /pets
///   @GET
///   func pets(@Query name: String? = nil) -> [Pets] {}
///
///   /// GET /users/{id}
///   @GET("/users/{id:Int}")
///   func getUser() -> User {}
/// }
/// ```
///
/// You can add custom APIClient modifiers such as `.header(_:)`, `.auth(enabled:)`, etc., in the function body using the `client` property.
/// ```swift
/// /// PUT /user
/// @PUT
/// func user(_ body: User) {
///   client
///     .auth(enabled: true)
/// }
/// ```
/// - Warning: If you use swiftformat disable unusedArguments rule: `--disable unusedArguments` or `//swiftformat:disable:unusedArguments`
@attached(peer, names: arbitrary)
public macro PUT(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

/// A macro that generates an HTTP **DELETE** call to the API client.
///
/// - Parameters:
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the function name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// Must be used with a function within a struct attributed with `@API` or `@Path` macro.
///
/// The function must have an empty body `{}` and return either a `Decodable` type, tuple, `String`, `Data`, or `Void`.
///
/// You can specify the body and query in two ways:
/// - `@Body` and `@Query` parameter attributes. These attributes add a parameter to the body or query with the same name as the parameter. If you specify two names, the second name will be used for the parameter name.
/// - Encodable or tuple parameters named `body` or `query`. These parameters will be encoded and used as body or query parameters as is.
///
/// Examples:
/// ```swift
/// @API
/// struct API {
///
///   /// GET /pets
///   @GET
///   func pets(@Query name: String? = nil) -> [Pets] {}
///
///   /// GET /users/{id}
///   @GET("/users/{id:Int}")
///   func getUser() -> User {}
/// }
/// ```
///
/// You can add custom APIClient modifiers such as `.header(_:)`, `.auth(enabled:)`, etc., in the function body using the `client` property.
/// ```swift
/// /// PUT /user
/// @PUT
/// func user(_ body: User) {
///   client
///     .auth(enabled: true)
/// }
/// ```
/// - Warning: If you use swiftformat disable unusedArguments rule: `--disable unusedArguments` or `//swiftformat:disable:unusedArguments`
@attached(peer, names: arbitrary)
public macro DELETE(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

/// A macro that generates an HTTP **PATCH** call to the API client.
///
/// - Parameters:
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the function name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// Must be used with a function within a struct attributed with `@API` or `@Path` macro.
///
/// The function must have an empty body `{}` and return either a `Decodable` type, tuple, `String`, `Data`, or `Void`.
///
/// You can specify the body and query in two ways:
/// - `@Body` and `@Query` parameter attributes. These attributes add a parameter to the body or query with the same name as the parameter. If you specify two names, the second name will be used for the parameter name.
/// - Encodable or tuple parameters named `body` or `query`. These parameters will be encoded and used as body or query parameters as is.
///
/// Examples:
/// ```swift
/// @API
/// struct API {
///
///   /// GET /pets
///   @GET
///   func pets(@Query name: String? = nil) -> [Pets] {}
///
///   /// GET /users/{id}
///   @GET("/users/{id:Int}")
///   func getUser() -> User {}
/// }
/// ```
///
/// You can add custom APIClient modifiers such as `.header(_:)`, `.auth(enabled:)`, etc., in the function body using the `client` property.
/// ```swift
/// /// PUT /user
/// @PUT
/// func user(_ body: User) {
///   client
///     .auth(enabled: true)
/// }
/// ```
/// - Warning: If you use swiftformat disable unusedArguments rule: `--disable unusedArguments` or `//swiftformat:disable:unusedArguments` 
@attached(peer, names: arbitrary)
public macro PATCH(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientCallMacro")

/// Macro that generates an API client scope for the path.
/// This macro synthesizes a variable or function that returns the path struct.
///
/// - Parameters:
///   - path: The path components to be appended to the base URL. If omitted, the path will be equal to the struct name. You can include arguments in the path using the following syntax: `{argument}` or, if you want to specify the type, `{argument:Int}`.
///
/// The struct can contain functions with `Call`, `GET`, `POST`, `PUT`, `PATCH`, and `DELETE` macros, as well as structs with the `Path` macro.
/// All included function paths will be resolved relative to the path specified in the `Path` macro.
/// If you specify a custom initializer, you must initialize the `client` property.
///
/// Examples:
/// ```swift
/// /// /pets
/// @Path
/// struct Pets {
///   /// DELETE /pets/{id}
///   @DELETE("{id}")
///   func deletePet()
/// }
/// ```
///
/// You can add custom APIClient modifiers for all methods in the struct, such as `.header(_:)`, `.auth(enabled:)`, etc., by implementing a custom init:
/// ```swift
/// init(client: APIClient) {
///   self.client = client.auth(enabled: true)
/// }
/// ```
@attached(peer, names: arbitrary)
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro Path(_ path: String...) = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientPathMacro")

/// Macro that generates an API client struct.
/// The struct can contain functions with `Call`, `GET`, `POST`, `PUT`, `PATCH`, and `DELETE` macros, as well as structs with the `Path` macro.
/// If you specify a custom init, you must initialize the `client` property.
@attached(memberAttribute)
@attached(member, names: arbitrary)
public macro API() = #externalMacro(module: "SwiftAPIClientMacros", type: "SwiftAPIClientPathMacro")

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
