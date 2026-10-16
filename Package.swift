// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
	name: "swift-api-client",
	platforms: [
		.macOS(.v10_15),
		.iOS(.v13),
		.watchOS(.v5),
		.tvOS(.v13),
	],
	products: [
		.library(name: "SwiftAPIClient", targets: ["SwiftAPIClient"]),
		.library(name: "SwiftAPIClientCore", targets: ["SwiftAPIClientCore"]),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.0"),
		.package(url: "https://github.com/apple/swift-metrics.git", from: "2.4.0"),
	],
	targets: [
		.target(
			name: "SwiftAPIClientCore",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "HTTPTypesFoundation", package: "swift-http-types"),
				.product(name: "Metrics", package: "swift-metrics")
			]
		),
		.target(
			name: "SwiftAPIClient",
			dependencies: [.target(name: "SwiftAPIClientCore")]
		),
		.testTarget(
			name: "SwiftAPIClientTests",
			dependencies: [.target(name: "SwiftAPIClient"), .target(name: "SwiftAPIClientCore")]
		),
	]
)
