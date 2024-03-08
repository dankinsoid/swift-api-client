# swift-networking-core
Lightweight core of the [swift-networking](https://github.com/dankinsoid/swift-networking.git) library.

`swift-networking-core` is a comprehensive, and modular client networking library for Swift.

## Main goals of the library
- Minimalistic and intuitive syntax.
- Reusability of any configurations through all requests.
- Extensebility and modularity.
- Simple core with a wide range of possibilities.
- Testability and mockability.

## Usage

Core of the library is `NetworkClient` struct. It is a request builder and a request executor at the same time. It is a generic struct, so you can use it for any task associated with `URLRequest`.\
While full example is in [Example folder](/Example/) here is a simple example of usage:
```swift

```

## Features
### Request building
### Request execution
### Testing
### Logging

## How to extend functionality

`NetworkClient` struct is a combination of two components: a closure to create a URLReauest and a typed dictionory of configs. So there is two ways to extend a NetworkClient.

## Installation

1. [Swift Package Manager](https://github.com/apple/swift-package-manager)

Create a `Package.swift` file.
```swift
// swift-tools-version:5.7
import PackageDescription

let package = Package(
  name: "SomeProject",
  dependencies: [
    .package(url: "https://github.com/dankinsoid/swift-networking-core.git", from: "0.18.0")
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
