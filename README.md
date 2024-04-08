`swift-api-client` is a comprehensive and modular Swift library for API design.

## Table of Contents
- [Table of Contents](#table-of-contents)
- [Main Goals of the Library](#main-goals-of-the-library)
- [Usage](#usage)
- [What is `APIClient`](#what-is-apiclient)
- [Built-in `APIClient` Extensions](#built-in-apiclient-extensions)
  - [Request building](#request-building)
  - [Request execution](#request-execution)
    - [`APIClientCaller`](#apiclientcaller)
    - [Serializer](#serializer)
    - [Some execution modifiers](#some-execution-modifiers)
  - [Encoding and Decoding](#encoding-and-decoding)
    - [ContentSerializer](#contentserializer)
  - [Auth](#auth)
    - [Token refresher](#token-refresher)
  - [Mocking](#mocking)
  - [Logging](#logging)
- [`APIClient.Configs`](#apiclientconfigs)
  - [Configs Modifications Order](#configs-modifications-order)
- [Macros](#macros)
- [Introducing `swift-api-client-addons`](#introducing-swift-api-client-addons)
- [Installation](#installation)
- [Author](#author)
- [License](#license)
- [Contributing](#contributing)
 
## Main Goals of the Library
- Minimalistic and intuitive syntax.
- Reusability, allowing for the injection of configurations across all requests.
- Extensibility and modularity.
- A simple core offering a wide range of possibilities.
- Facilitation of testing and mocking.

## Usage
The core of the library is the `APIClient` struct, serving both as a request builder and executor. It is a generic struct, enabling use for any task associated with URL request.

The branching and configuration injection/overriding capabilities of APIClient, extending to all its child instances, facilitate the effortless recycling of networking logic and tasks, thereby eliminating the need for copy-pasting.

While a full example is available in the [Example folder](/Example/), here is a simple usage example:
```swift
let client = APIClient(url: baseURL)
  .bodyDecoder(.json(dateDecodingStrategy: .iso8601))
  .bodyEncoder(.json(dateEncodingStrategy: .iso8601))
  .errorDecoder(.decodable(APIError.self))
  .tokenRefresher { refreshToken, client, _ in
    guard let refreshToken else { throw APIError.noRefreshToken }
    let tokens: AuthTokens = try await client("auth", "token")
        .body(["refresh_token": refreshToken])
        .post()
    return (tokens.accessToken, tokens.refreshToken, tokens.expiresIn)
  } auth: {
    .bearer(token: $0)
  }

// Create a `APIClient` instance for the /users path
let usersClient = client("users")

// GET /users?name=John&limit=1
let john: User = try await usersClient
  .query(["name": "John", "limit": 1])
  .auth(enabled: false)
  .get()

// Create a `APIClient` instance for /users/{userID} path
let johnClient = usersClient(john.id)

// GET /user/{userID}
let user: User = try await johnClient.get()

// PUT /user/{userID}
try await johnClient.body(updatedUser).put()

// DELETE /user/{userID}
try await johnClient.delete()
```

Also, you can use macros for API declaration:
```swift
/// /pet
@Path
struct Pet {

  /// PUT /pet
  @PUT("/") public func update(_ body: PetModel) -> PetModel {}

  /// POST /pet
  @POST("/") public func add(_ body: PetModel) -> PetModel {}

  /// GET /pet/findByStatus
  @GET public func findByStatus(@Query _ status: PetStatus) -> [PetModel] {}

  /// GET /pet/findByTags
  @GET public func findByTags(@Query _ tags: [String]) -> [PetModel] {}
}
```

## What is `APIClient`

`APIClient` is a struct combining a closure for creating a URL request and a typed dictionary of configurations `APIClient.Configs`. There are two primary ways to extend a `APIClient`:
- `modifyRequest` modifiers.
- `configs` modifiers.

Executing an operation on the client involves:
- `withRequest` methods.

All built-in extensions utilize these modifiers.
## Built-in `APIClient` Extensions
The full list is available [in docs](https://dankinsoid.github.io/swift-api-client/documentation/swiftapiclient/apiclient).
### Request building
Numerous methods exist for modifying a URL request such as `query`, `body`, `header`, `headers`, `method`, `path`, `body` and more.
```swift
let client = APIClient(url: baseURL)
  .method(.post)
  .body(someEncodableBody)
  .query(someEncodableQuery)
  .header(.acceptEncoding, "UTF-8")
```
The full list of modifiers is available in [RequestModifiers.swift](/Sources/SwiftAPIClient/Modifiers/RequestModifiers.swift), all based on the `modifyRequest` modifier.

Notable non-obvious modifiers include:
- `.callAsFunction(path...)` - as a shorthand for the `.path(path...)` modifier, allowing `client("path")` instead of `client.path("path")`.
- HTTP method shorthands like `.get`, `.post`, `.put`, `.delete`, `.patch`.

### Request execution
The method`call(_ caller: APIClientCaller<...>, as serializer: Serializer<...>)` is provided.
Examples:
```swift
try await client.call(.http, as: .decodable)
try await client.call(.http, as: .void)
try client.call(.httpPublisher, as: .decodable)
```
There are also shorthands for built-in callers and serializers:
- `call()` is equivalent to `call(.http, as: .decodable)` or `call(.http, as: .void)`
- `callAsFunction()` acts as `call()`, simplifying `client.delete()` to `client.delete.call()` or  `client()` instead of `client.call()`, etc.

#### `APIClientCaller`
Defines request execution with several built-in callers for various request types, including:
- `.http` for HTTP requests using `try await` syntax.
- `.httpPublisher` for HTTP requests with Combine syntax.
- `.httpDownload` for HTTP download requests using `try await` syntax.
- `.mock` for mock requests using `try await` syntax.

All built-in HTTP callers use the `.httpClient` configuration, which can be customized with the `.httpClient()` modifier. The default `.httpClient` is `URLSession`. It's possible to customize the current `.httpClient` instance.

Custom callers can be created for different types of requests, such as WebSocket, GraphQL, etc.

#### Serializer
`Serializer` is a struct that describes response serialization with several built-in serializers:
- `.decodable` for decoding a response into a Decodable type.
- `.data` for obtaining a raw Data response.
- `.void` for ignoring the response.
- `.instance` for receiving a response of the same type as `APIClientCaller` returns. For HTTP requests, it is `Data`.

The `.decodable` serializer uses the `.bodyDecoder` configuration, which can be customized with the `.bodyDecoder` modifier. The default `bodyDecoder` is `JSONDecoder()`.

#### Some execution modifiers
- `.retry(limit:)` for retrying a request a specified number of times.
- `.throttle(interval:)` for throttling requests with a specified interval.
- `.timeout(_:)` for setting an execution timeout.
- `.waitForConnection()` for waiting for a connection before executing a request.
- `.backgroundTask()` for executing a request in the background task.
- `.retryIfFailedInBackground()` for retrying a request if it fails in the background.

### Encoding and Decoding
There are several built-in configurations for encoding and decoding:
- `.bodyEncoder` for encoding a request body. Built-in encoders include `.json`, `.formURL` and `.multipartFormData`.
- `.bodyDecoder` for decoding a request body. The built-in decoder is `.json`.
- `.queryEncoder` for encoding a query. The built-in encoder is `.query`.
- `.errorDecoder` for decoding an error response. The built-in decoder is `.decodable(type)`.

These encoders and decoders can be customized with corresponding modifiers.

#### ContentSerializer
`ContentSerializer` is a struct that describes request body serialization, with one built-in content serializer: `.encodable` that utilizes the `.bodyEncoder` configuration.
Custom content serializers can be specified by passing a `ContentSerializer` instance to the `.body(_:as:)` modifier.

### Auth
`.auth` and `.isAuthEnabled` configurations can be customized with `.auth(_:)` and `.auth(enabled:)` modifiers,
allowing the injection of an authentication type for all requests and enabling/disabling it for specific requests.

The `.auth` configuration is an `AuthModifier` instance with several built-in `AuthModifier` types:
- `.bearer(token:)` for Bearer token authentication.
- `.basic(username:password:)` for Basic authentication.
- `.apiKey(key:field:)` for API Key authentication.

#### Token refresher
The `.tokenRefresher(...)` modifier can be used to specify a token refresher closure, which is called when a request returns a 401 status code. The refresher closure receives the cached refresh token, the client, and the response, and returns a new token, which is then used for the request. `.refreshToken` also sets the `.auth` configuration.

### Mocking
Built-in tools for mocking requests include:
- `.mock(_:)` modifier to specify a mocked response for a request.
- `Mockable` protocol allows any request returning a `Mockable` response to be mocked even without the `.mock(_:)` modifier.
- `.usingMocksPolicy` configuration defines whether to use mocks, customizable with `.usingMocks(policy:)` modifier.
By default, mocks are ignored in the `live` environment and used as specified for tests and SwiftUI previews.

Additionally, `.mock(_:)` as a `APIClientCaller` offers an alternative way to mock requests, like `client.call(.mock(data), as: .decodable)`.

Custom HTTPClient instances can also be created and injected for testing or previews.

### Logging
`swift-api-client` employs `swift-log` for logging, with `.logger` and `.logLevel` configurations customizable via `logger` and `.log(level:)` modifiers.
The default log level is `.info`. A built-in `.none` Logger is available to disable all logs.

Log example:

```
[29CDD5AE-1A5D-4135-B76E-52A8973985E4] ModuleName/FileName.swift/72
--> 🌐 PUT /petstore (9-byte body)
Content-Type: application/json
--> END PUT
[29CDD5AE-1A5D-4135-B76E-52A8973985E4]
<-- ✅ 200 OK (100ms, 15-byte body)
```
Log message format can be customized with the `.loggingComponents(_:)` modifier.

## `APIClient.Configs`
A collection of config values is propagated through the modifier chain. These configs are accessible in all core methods: `modifyRequest`, `withRequest`, and `withConfigs`.

To create custom config values, extend the `APIClient.Configs` structure with a new property.
Use subscript with your property key path to get and set the value, and provide a dedicated modifier for clients to use when setting this value:
```swift
extension APIClient.Configs {
  var myCustomValue: MyConfig {
    get {
      self[\.myCustomValue] ?? myDefaultConfig
    }
    set {
      self[\.myCustomValue] = newValue
    }
  }
}

extension APIClient {
  func myCustomValue(_ myCustomValue: MyConfig) -> APIClient {
    configs(\.myCustomValue, myCustomValue)
  }
}
```

There is `valueFor` global method that allows you to define default values depending on the environment: live, test or preview.

### Configs Modifications Order
All configs are collected in the final `withRequest` method and then passed to all modifiers, so the last defined value is used.
Note that all execution methods, like `call`, are based on the `withRequest` method.

For instance, the following code will print `3` in all cases:
```swift
let configs = try client
  .configs(\.intValue, 1)
  .modifyRequest { _, configs in
    print(configs.intValue) // 3
  }
  .configs(\.intValue, 2)
  .modifyRequest { _, configs in
    print(configs.intValue) // 3
  }
  .configs(\.intValue, 3)
  .withRequest { _, configs in
    print(configs.intValue)  // 3
    return configs
  }
print(configs.intValue) // 3
```

## Macros
`swift-api-client` provides a set of macros for easier API declarations.
- `API` macro that generates an API client struct.
- `Path` macro that generates an API client scope for the path.
- `Cal(_ method:)`, `GET`, `POST`, `PUT`, etc macros for declaring API methods.
Example:
```swift
/// /pet
@Path
struct Pet {

  /// PUT /pet
  @PUT("/") public func update(_ body: PetModel) -> PetModel {}

  /// POST /pet
  @POST("/") public func add(_ body: PetModel) -> PetModel {}

  /// GET /pet/findByStatus
  @GET public func findByStatus(@Query _ status: PetStatus) -> [PetModel] {}

  /// GET /pet/findByTags
  @GET public func findByTags(@Query _ tags: [String]) -> [PetModel] {}

  /// /pet/{id}
  @Path("{id}")
  public struct PetByID {

    /// GET /pet/{id}
    @GET("/")
    func get() -> PetModel {}

    /// DELETE /pet/{id}
    @DELETE("/")
    func delete() {}

    /// POST /pet/{id}
    @POST("/") public func update(@Query name: String?, @Query status: PetStatus?) -> PetModel {}

    /// POST /pet/{id}/uploadImage
    @POST public func uploadImage(_ body: Data, @Query additionalMetadata: String? = nil) {}
  }
}
```
Macros are not necessary for using `swift-api-client`; they are just syntax sugar.

## Introducing `swift-api-client-addons`

To enhance your experience with `swift-api-client`, I'm excited to introduce [`swift-api-client-addons`](https://github.com/dankinsoid/swift-api-client-addons) 
— a complementary library designed to extend the core functionality of `swift-api-client` with additional features and utilities.

## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/swift-api-client.git", from: "1.5.13")
  ],
  targets: [
    .target(
      name: "SomeProject",
      dependencies: [
        .product(name:  "SwiftAPIClient", package: "swift-api-client"),
      ]
    )
  ]
)
```
```ruby
$ swift build
```

## Author

Daniil Voidilov, voidilov@gmail.com

## License

swift-api-client is available under the MIT license. See the LICENSE file for more info.

## Contributing
We welcome contributions to Swift-Networking! Please read our contributing guidelines to get started.
