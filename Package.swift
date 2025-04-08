// swift-tools-version: 6.0
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "MacosUseSDK",
    platforms: [
        .macOS(.v12)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "MacosUseSDK",
            targets: ["MacosUseSDK"]),
        .executable(
            name: "SDKTool",
            targets: ["SDKTool"]),
        // Comment out the old tool products
        // .executable(
        //     name: "TraversalTool",
        //     targets: ["TraversalTool"]),
        // .executable(
        //     name: "HighlightTraversalTool",
        //     targets: ["HighlightTraversalTool"]),
        // .executable(
        //     name: "InputControllerTool",
        //     targets: ["InputControllerTool"]),
        // .executable(
        //     name: "VisualInputTool",
        //     targets: ["VisualInputTool"]),
        // .executable(
        //     name: "AppOpenerTool",
        //     targets: ["AppOpenerTool"]),
        // Keep the test tool if you created it
    ],
    dependencies: [
        .package(url: "https://github.com/apple/swift-argument-parser", from: "1.3.0"),
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "MacosUseSDK",
            dependencies: [],
            linkerSettings: [
                .linkedFramework("AppKit"),
                .linkedFramework("ApplicationServices"),
            ]
        ),
        .executableTarget(
            name: "SDKTool",
            dependencies: [
                "MacosUseSDK",
                .product(name: "ArgumentParser", package: "swift-argument-parser"),
            ]
        ),
        // Comment out the old tool targets
        // .executableTarget(
        //     name: "TraversalTool",
        //     dependencies: ["MacosUseSDK"]
        // ),
        // .executableTarget(
        //     name: "HighlightTraversalTool",
        //     dependencies: [
        //         "MacosUseSDK",
        //     ]
        // ),
        // .executableTarget(
        //     name: "InputControllerTool",
        //     dependencies: ["MacosUseSDK"]
        // ),
        // .executableTarget(
        //     name: "VisualInputTool",
        //     dependencies: ["MacosUseSDK"]
        // ),
        // .executableTarget(
        //     name: "AppOpenerTool",
        //     dependencies: ["MacosUseSDK"]
        // ),
        // Keep the test tool target if you created it
    ]
)
