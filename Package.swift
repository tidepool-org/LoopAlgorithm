// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.

import PackageDescription

let package = Package(
    name: "LoopAlgorithm",
    platforms: [
        .macOS(.v13),
        .iOS(.v15),
        .tvOS(.v15),
        .watchOS(.v8)
    ],
    products: [
        // Products define the executables and libraries a package produces, making them visible to other packages.
        .library(
            name: "LoopAlgorithm",
            targets: ["LoopAlgorithm"]),
        .executable(name: "LoopAlgorithmRunner", targets: ["LoopAlgorithmRunner"])
    ],
    targets: [
        // Targets are the basic building blocks of a package, defining a module or a test suite.
        // Targets can depend on other targets in this package and products from dependencies.
        .target(
            name: "LoopAlgorithm"
        ),
        .executableTarget(
                    name: "LoopAlgorithmRunner",
                    dependencies: ["LoopAlgorithm"]
        ),
        .testTarget(
            name: "LoopAlgorithmTests",
            dependencies: ["LoopAlgorithm"],
            resources: [
                .copy("Fixtures")
            ]
        )
    ]
)
