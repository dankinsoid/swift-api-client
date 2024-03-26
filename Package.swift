// swift-tools-version:5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import CompilerPluginSupport
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
	],
	dependencies: [
		.package(url: "https://github.com/apple/swift-log.git", from: "1.5.3"),
		.package(url: "https://github.com/apple/swift-http-types.git", from: "1.0.3"),
		.package(url: "https://github.com/apple/swift-syntax.git", from: "509.0.2"),
	],
	targets: [
		.target(
			name: "SwiftAPIClient",
			dependencies: [
				.target(name: "SwiftAPIClientMacros"),
				.product(name: "Logging", package: "swift-log"),
				.product(name: "HTTPTypes", package: "swift-http-types"),
				.product(name: "HTTPTypesFoundation", package: "swift-http-types"),
			]
		),
		.testTarget(
			name: "SwiftAPIClientTests",
			dependencies: [.target(name: "SwiftAPIClient")]
		),
		.macro(
			name: "SwiftAPIClientMacros",
			dependencies: [
				.product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
				.product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
			]
		),
	]
)
