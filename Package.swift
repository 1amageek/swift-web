// swift-tools-version: 6.3

import CompilerPluginSupport
import PackageDescription

let swiftWebSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
]

let swiftWebCoreOnly = Context.environment["SWIFTWEB_CORE_ONLY"] == "1"

let swiftHTMLDependency: Target.Dependency = .product(name: "SwiftHTML", package: "swift-html")

let swiftWebUIDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
    "SwiftWebStyle",
]

let swiftWebUIRuntimeDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
    .product(name: "JavaScriptKit", package: "JavaScriptKit"),
    "SwiftWebActors",
    "SwiftWebStyle",
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
        .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
        .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
    ] : [
        .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
        .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
        .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
        .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
        .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
        .library(name: "SwiftWebDevelopmentHooks", targets: ["SwiftWebDevelopmentHooks"]),
        .library(name: "SwiftWebDevelopment", targets: ["SwiftWebDevelopment"]),
        .library(name: "SwiftWebStoryboard", targets: ["SwiftWebStoryboard"]),
        .executable(name: "sweb", targets: ["SwiftWebCLI"]),
    ],
    dependencies: [
        .package(path: "../swift-html"),
        .package(url: "https://github.com/1amageek/JavaScriptKit.git", branch: "main"),
        .package(url: "https://github.com/1amageek/swift-actor-runtime.git", exact: "0.5.0"),
    ] + (swiftWebCoreOnly ? [] : [
        .package(url: "https://github.com/vapor/vapor.git", revision: "fff4892930e69b49ea2612699bed9583721723dc"),
        .package(url: "https://github.com/vapor/routing-kit.git", from: "5.0.0-beta"),
        .package(url: "https://github.com/vapor/websocket-kit.git", from: "2.13.0"),
        .package(url: "https://github.com/swift-server/async-http-client.git", revision: "393104434ea57710f2469036e816672fe15e8212"),
        .package(url: "https://github.com/swift-server/swift-http-server", revision: "b1c4f775dfbdc74800c0f29fda79c8984a5e9073"),
        .package(url: "https://github.com/apple/swift-http-api-proposal.git", revision: "d58fd6fa157e08bff44aa360ff83ebd424783392"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.82.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "602.0.0"),
    ]),
    targets: swiftWebCoreOnly ? [
        .target(
            name: "SwiftWebStyle",
            dependencies: [swiftHTMLDependency],
            swiftSettings: swiftWebSwiftSettings
        ),
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
            name: "SwiftWebStyle",
            dependencies: [swiftHTMLDependency],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebActors",
            dependencies: swiftWebActorsDependencies,
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebCore",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "Vapor", package: "vapor"),
                .product(name: "RoutingKit", package: "routing-kit"),
                .product(name: "WebSocketKit", package: "websocket-kit"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWeb",
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWeb",
            dependencies: [
                "SwiftWebCore",
                "SwiftWebMacros",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebFacade",
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
        .target(
            name: "SwiftWebDevelopmentHooks",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "Vapor", package: "vapor"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                "SwiftWebCore",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebDevelopment",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "Vapor", package: "vapor"),
                .product(name: "HTTPAPIs", package: "swift-http-api-proposal"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOHTTPServer", package: "swift-http-server"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                "SwiftWebCore",
                "SwiftWebDevelopmentHooks",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebStoryboard",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWeb",
                "SwiftWebStyle",
                "SwiftWebUI",
                "SwiftWebUIRuntime",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .executableTarget(
            name: "SwiftWebCLI",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebCore",
                "SwiftWebUI",
                "SwiftWebDevelopment",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebUITests",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebUI",
                "SwiftWebStoryboard",
                "SwiftWebStyle",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebUIRuntimeTests",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebUIRuntime",
                "SwiftWebUI",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebTests",
            dependencies: [
                "SwiftWeb",
                "SwiftWebUI",
                "SwiftWebDevelopmentHooks",
                "SwiftWebDevelopment",
                .product(name: "VaporTesting", package: "vapor"),
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
