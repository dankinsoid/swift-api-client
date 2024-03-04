# swift-networking-core
Core of the [swift-networking](https://github.com/dankinsoid/swift-networking.git) library.

## Overview
Swift-Networking is a modern, comprehensive, and modular networking library for Swift. Designed with a focus on extensibility and reusability, it simplifies building and managing complex networking tasks in your Swift applications. The library supports a wide range of networking needs, from HTTP requests to WebSocket communication, and is easily testable and mockable.

Swift-networking focuses on extensibility and reusability of all configs. The root of the library is NetworkClient struct. The main idea is that you can create a client with a base URL and then create new clients from it, which will inherit all the settings of the parent client. For example, you can create a client for the API with the base URL "https://api.github.com" and then create a client for the API with the base URL "https://api.github.com/users" from it. The second client will inherit all the settings of the first client, but you can override them if necessary. 
There is a list of all implemented configs.
// TODO: finish
Basically NetworkClient is a combination of two components: a closure to create a URLReauest and a dictionory of configs. So there is two ways to extend a NetworkClient.
- Add a new config.
- Add a new URLRequest modifier.

```swift


## Usage
Below is an example of using Swift-Networking to create an API client for a [Petstore](https://petstore3.swagger.io):

```swift
struct Petstore {

  enum BaseURL: String {

    case production = "https://petstore.com"
    case staging = "https://staging.petstore.com"
    case test = "http://localhost:8080"
  }

  var client: NetworkClient

  init(baseURL: BaseURL, token: String) {
    client = NetworkClient(baseURL: URL(string: baseURL.rawValue)!)
      .bodyDecoder(.json(dateDecodingStrategy: .iso8601, keyDecodingStrategy: .convertFromSnakeCase))
      .auth(.bearer(token: token))
  }

  var pet: Pet {
    Pet(client: client["pet"])
  }

  var store: Store {
    Store(client: client["store"].auth(enabled: false))
  }

  var user: User {
    User(client: client["user"].auth(enabled: false))
  }

  struct Pet {

    var client: NetworkClient

    func update(_ pet: PetModel) async throws -> PetModel {
      try await client
        .method(.put)
        .body(pet)
        .call(.http, as: .decodable)
    }

    func add(_ pet: PetModel) async throws -> PetModel {
      try await client
        .method(.post)
        .body(pet)
        .call(.http, as: .decodable)
    }

    func findBy(status: PetStatus) async throws -> [PetModel] {
      try await client["findByStatus"]
        .query("status", status)
        .call(.http, as: .decodable)
    }

    func findBy(tags: [String]) async throws -> [PetModel] {
      try await client["findByTags"]
        .query("tags", tags)
        .call(.http, as: .decodable)
    }

    func callAsFunction(_ id: String) -> PetByID {
      PetByID(client: client.path(id))
    }

    struct PetByID {

      var client: NetworkClient

      func get() async throws -> PetModel {
        try await client.call(.http, as: .decodable)
      }

      func update(name: String?, status: PetStatus?) async throws -> PetModel {
        try await client
          .method(.post)
          .query(["name": name, "status": status])
          .call(.http, as: .decodable)
      }

      func delete() async throws -> PetModel {
        try await client
          .method(.delete)
          .call(.http, as: .decodable)
      }

      func uploadImage(_ image: Data, additionalMetadata: String? = nil) async throws {
        try await client["uploadImage"]
          .method(.post)
          .query("additionalMetadata", additionalMetadata)
          .body(image)
          .headers(.contentType(.application(.octetStream)))
          .call(.http, as: .void)
      }
    }
  }

  struct Store {

    var client: NetworkClient

    func inventory() async throws -> [String: Int] {
      try await client["inventory"]
        .auth(enabled: true)
        .call(.http, as: .decodable)
    }

    func order(_ model: OrderModel) async throws -> OrderModel {
      try await client["order"]
        .body(model)
        .method(.post)
        .call(.http, as: .decodable)
    }

    func callAsFunction(_ id: String) -> Order {
      Order(client: client.path("order", id))
    }

    struct Order {

      var client: NetworkClient

      func find() async throws -> OrderModel {
        try await client.call(.http, as: .decodable)
      }

      func delete() async throws -> OrderModel {
        try await client
          .method(.delete)
          .call(.http, as: .decodable)
      }
    }
  }

  struct User {

    var client: NetworkClient

    func create(_ model: UserModel) async throws -> UserModel {
      try await client
        .method(.post)
        .body(model)
        .call(.http, as: .decodable)
    }

    func createWith(list: [UserModel]) async throws {
      try await client["createWithList"]
        .method(.post)
        .body(list)
        .call(.http, as: .void)
    }

    func login(username: String, password: String) async throws -> String {
      try await client["login"]
        .query(LoginQuery(username: username, password: password))
        .call(.http, as: .decodable)
    }

    func logout() async throws {
      try await client["logout"].call(.http, as: .void)
    }

    func callAsFunction(_ username: String) -> UserByUsername {
      UserByUsername(client: client.path(username))
    }

    struct UserByUsername {

      var client: NetworkClient

      func get() async throws -> UserModel {
        try await client
          .call(.http, as: .decodable)
      }

      func update(_ model: UserModel) async throws -> UserModel {
        try await client
          .method(.put)
          .body(model)
          .call(.http, as: .decodable)
      }

      func delete() async throws -> UserModel {
        try await client
          .method(.delete)
          .call(.http, as: .decodable)
      }
    }
  }
}

// MARK: - Usage example

func exampleOfUsage() async throws {
    let api = Petstore(baseURL: .production, token: "token")

    _ = try await api.pet("some-id").get()
    _ = try await api.pet.findBy(status: .available)
    _ = try await api.store.inventory()
    _ = try await api.user.logout()
    _ = try await api.user("name").delete()
}
```

This example demonstrates how to configure and use various aspects of the library, such as configuring endpoints, handling authentication, and processing responses.

## Customization
The library is designed for flexibility and can be easily customized to suit different networking needs:

- **Custom Encoders and Decoders**: Easily implement custom logic for request and response processing.
- **Authentication Handling**: Seamlessly integrate authentication mechanisms.
- **Error Handling and Logging**: Customize how errors are handled and logged.

## Testing
Swift-Networking supports easy testing and mocking of network clients, making it simple to write unit tests for your networking code.

## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/swift-networking-core.git", from: "0.1.0")
  ],
  targets: [
    .target(
      name: "SomeProject",
      dependencies: [
        .product(name:  "SwiftNetworkingCore", package: "swift-networking-core"),
      ]
    )
  ]
)
```
```ruby
$ swift build
```

## Author

dankinsoid, voidilov@gmail.com

## License

swift-networking-core is available under the MIT license. See the LICENSE file for more info.

## Contributing
We welcome contributions to Swift-Networking! Please read our contributing guidelines to get started.
