// swift-tools-version: 6.1

import PackageDescription

let package = Package(
    name: "HuggingChatKit",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
        .visionOS(.v1),
    ],
    products: [
        // Shims the AnyLanguageModel package with MLX support enabled
        .library(
            name: "HuggingChatKit",
            targets: ["HuggingChatKit"]
        )
    ],
    dependencies: [
        .package(
            url: "https://github.com/mattt/AnyLanguageModel", 
            branch: "main", 
            traits: [
                .trait(name: "MLX"),
            ]
        )
    ],
    targets: [
        .target(
            name: "HuggingChatKit",
            dependencies: [
                .product(name: "AnyLanguageModel", package: "AnyLanguageModel")
            ]
        )
    ]
)
