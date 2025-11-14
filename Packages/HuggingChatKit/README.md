# HuggingChatKit

The HuggingChat app target depends on 
[AnyLanguageModel](https://github.com/mattt/AnyLanguageModel).
However, Xcode 26 doesn't yet provide a built-in way to declare this dependency with the  
[package trait](https://docs.swift.org/swiftpm/documentation/packagemanagerdocs/packagetraits/)
needed to build the package with support for 
[MLX](https://github.com/ml-explore/mlx-swift-lm).

As a workaround,
we create an internal package with Swift Package Manager
that _does_ support package traits to act as a shim,
exporting the `AnyLanguageModel` module with MLX support enabled.
The Xcode project for the app can then add this internal package as a local dependency.
