// swift-tools-version: 6.4

import PackageDescription

let sharedSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
]

let package = Package(
    name: "swift-actor-system",
    platforms: [
        .macOS(.v15),
    ],
    products: [
        .library(name: "ActorSystemCore", targets: ["ActorSystemCore"]),
        .library(name: "ActorSystemDistributed", targets: ["ActorSystemDistributed"]),
        .library(name: "ActorSystemEmbedded", targets: ["ActorSystemEmbedded"]),
        .library(name: "ActorSystemGeneration", targets: ["ActorSystemGeneration"]),
        .library(name: "ActorSystemBuildSupport", targets: ["ActorSystemBuildSupport"]),
        .library(name: "ActorSystemCompatibility", targets: ["ActorSystemCompatibility"]),
        .library(name: "ActorSystemTestSupport", targets: ["ActorSystemTestSupport"]),
        .executable(name: "actor-system", targets: ["ActorSystemTool"]),
    ],
    dependencies: [
        .package(
            url: "https://github.com/1amageek/swift-actor-runtime.git",
            exact: "0.6.0"
        ),
        .package(
            url: "https://github.com/swiftlang/swift-syntax.git",
            from: "603.0.2"
        ),
    ],
    targets: [
        .target(
            name: "ActorSystemCore",
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ActorSystemDistributed",
            dependencies: ["ActorSystemCore"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ActorSystemEmbedded",
            dependencies: ["ActorSystemCore"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ActorSystemGeneration",
            dependencies: [
                "ActorSystemCore",
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftIfConfig", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ActorSystemBuildSupport",
            dependencies: ["ActorSystemGeneration"],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ActorSystemCompatibility",
            dependencies: [
                "ActorSystemCore",
                .product(name: "ActorRuntime", package: "swift-actor-runtime"),
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .target(
            name: "ActorSystemTestSupport",
            dependencies: ["ActorSystemCore"],
            swiftSettings: sharedSwiftSettings
        ),
        .executableTarget(
            name: "ActorSystemTool",
            dependencies: [
                "ActorSystemBuildSupport",
                "ActorSystemGeneration",
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ActorSystemCoreTests",
            dependencies: [
                "ActorSystemCore",
                "ActorSystemTestSupport",
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ActorSystemDistributedTests",
            dependencies: [
                "ActorSystemDistributed",
                "ActorSystemTestSupport",
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ActorSystemEmbeddedTests",
            dependencies: [
                "ActorSystemEmbedded",
                "ActorSystemTestSupport",
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ActorSystemGenerationTests",
            dependencies: ["ActorSystemGeneration"],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ActorSystemBuildSupportTests",
            dependencies: [
                "ActorSystemBuildSupport",
                "ActorSystemGeneration",
            ],
            swiftSettings: sharedSwiftSettings
        ),
        .testTarget(
            name: "ActorSystemCompatibilityTests",
            dependencies: [
                "ActorSystemCompatibility",
                "ActorSystemCore",
            ],
            swiftSettings: sharedSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
