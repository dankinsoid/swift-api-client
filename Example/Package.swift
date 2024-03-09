// swift-tools-version:5.7
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

var package = Package(
	name: "pet-store",
	platforms: [
		.macOS(.v10_15),
		.iOS(.v13),
		.watchOS(.v5),
		.tvOS(.v13),
	],
	products: [
		.library(name: "PetStore", targets: ["PetStore"]),
	],
	dependencies: [
		.package(path: "../"),
	],
	targets: [
		.target(
			name: "PetStore",
			dependencies: [
				.product(name: "SwiftNetworking", package: "swift-networking"),
			]
		),
	]
)
