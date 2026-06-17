// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let swiftWebSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
]

let swiftWebCoreOnly = Context.environment["SWIFTWEB_CORE_ONLY"] == "1"

let swiftHTMLDependency: Target.Dependency = .product(name: "SwiftHTML", package: "swift-html")

let swiftWebUIDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
]

let swiftWebUIRuntimeDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
    .product(name: "JavaScriptKit", package: "JavaScriptKit"),
    "SwiftWebActors",
]

let swiftWebActorsDependencies: [Target.Dependency] = [
    .product(name: "ActorRuntime", package: "swift-actor-runtime"),
]

let package = Package(
    name: "swift-web",
    platforms: [
        .macOS("26.2"),
    ],
    products: swiftWebCoreOnly ? [
        .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
        .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
    ] : [
        .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
        .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
        .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
        .executable(name: "swift-web", targets: ["SwiftWebCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/swift-html.git", from: "0.2.1"),
        .package(url: "https://github.com/swiftwasm/JavaScriptKit.git", from: "0.55.0"),
        .package(url: "https://github.com/1amageek/swift-actor-runtime.git", exact: "0.5.0"),
    ] + (swiftWebCoreOnly ? [] : [
        .package(url: "https://github.com/vapor/vapor.git", revision: "8cfd55759c9f9e30ebdb95e30a3e80d96563f3fd"),
        .package(url: "https://github.com/vapor/routing-kit.git", from: "5.0.0-beta"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.13.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.82.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ]),
    targets: swiftWebCoreOnly ? [
        .target(
            name: "SwiftWebActors",
            dependencies: swiftWebActorsDependencies,
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUI",
            dependencies: swiftWebUIDependencies,
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUIRuntime",
            dependencies: swiftWebUIRuntimeDependencies,
            swiftSettings: swiftWebSwiftSettings
        ),
    ] : [
        .macro(
            name: "SwiftWebMacros",
            dependencies: [
                .product(name: "SwiftCompilerPlugin", package: "swift-syntax"),
                .product(name: "SwiftDiagnostics", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                .product(name: "SwiftSyntaxBuilder", package: "swift-syntax"),
                .product(name: "SwiftSyntaxMacros", package: "swift-syntax"),
            ],
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebActors",
            dependencies: swiftWebActorsDependencies,
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWeb",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "Vapor", package: "vapor"),
                .product(name: "RoutingKit", package: "routing-kit"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                "SwiftWebActors",
                "SwiftWebMacros",
            ],
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUI",
            dependencies: swiftWebUIDependencies,
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUIRuntime",
            dependencies: swiftWebUIRuntimeDependencies,
            swiftSettings: swiftWebSwiftSettings
        ),
        .executableTarget(
            name: "SwiftWebCLI",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWeb",
                "SwiftWebUI",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebUITests",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebUI",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebUIRuntimeTests",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebUIRuntime",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebTests",
            dependencies: [
                "SwiftWeb",
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
