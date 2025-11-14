// swift-tools-version: 6.2
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "HuggingChatKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "HuggingChatKit",
            targets: ["HuggingChatKit"]
        )
    ],
    dependencies: [
        .package(url: "https://github.com/mattt/AnyLanguageModel", branch: "main", traits: [.trait(name: "MLX")])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "HuggingChatKit",
            dependencies: [
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel")
            ]
        ),
        .testTarget(
            name: "HuggingChatKitTests",
            dependencies: ["HuggingChatKit"]
        ),
    ]
)
