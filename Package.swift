// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
	name: "swift-networking",
	platforms: [
		.macOS(.v10_15),
		.iOS(.v13),
		.watchOS(.v5),
		.tvOS(.v13),
	],
	products: [
		.library(name: "SwiftNetworking", targets: ["SwiftNetworking"]),
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
	],
	targets: [
		.target(
			name: "SwiftNetworking",
			dependencies: [
				.product(name: "Logging", package: "swift-log"),
			]
		),
		.testTarget(
			name: "SwiftNetworkingTests",
			dependencies: [.target(name: "SwiftNetworking")]
		),
	]
)
