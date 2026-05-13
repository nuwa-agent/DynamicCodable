// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "DynamicCodable",
    platforms: [
        .macOS(.v13), .iOS(.v16)
    ],
    products: [
      .library(
        name: "DynamicCodable",
        targets: ["DynamicCodable"]),
      .library(
        name: "YAML",
        targets: ["YAML"]),
      .library(
        name: "TOML",
        targets: ["TOML"]),
      .library(
        name: "JSON",
        targets: ["JSON"]),
    ],
    dependencies: [
        // Swift Argument Parser
        .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.7.1"),
        // Swift OrderedCollections
        .package(url: "https://github.com/apple/swift-collections", from: "1.5.0"),
    ],
    targets: [
        .target(
            name: "DynamicCodable",
            dependencies: [
                .product(name: "OrderedCollections", package: "swift-collections"),
            ],
            path: "Sources/DynamicCodable",
            exclude: ["README.md"]
        ),
        .target(
            name: "YAML",
            dependencies: [
                .target(name: "DynamicCodable"),
            ],
            path: "Sources/YAML",
            exclude: ["README.md"]
        ),
        .target(
            name: "JSON",
            dependencies: [
                .target(name: "DynamicCodable"),
            ],
            path: "Sources/JSON",
            exclude: ["README.md"]
        ),
        .target(
            name: "TOML",
            dependencies: [
                .target(name: "DynamicCodable"),
            ],
            path: "Sources/TOML",
            exclude: ["README.md"]
        ),
        .executableTarget(
            name: "Example",
            dependencies: ["DynamicCodable", "JSON", "YAML", "TOML"],
            path: "Example/Sources",
            exclude: ["README.md"]
        ),
        .testTarget(
            name: "TOMLTests",
            dependencies: ["TOML", "DynamicCodable"],
            path: "Tests/TOMLTests"
        ),
        .testTarget(
            name: "JSONTests",
            dependencies: ["JSON", "DynamicCodable"],
            path: "Tests/JSONTests"
        ),
        .testTarget(
            name: "YAMLTests",
            dependencies: ["YAML", "DynamicCodable"],
            path: "Tests/YAMLTests"
        ),
    ]
)
