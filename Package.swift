// swift-tools-version: 6.4

import CompilerPluginSupport
import PackageDescription

let swiftWebSwiftSettings: [SwiftSetting] = [
    .enableUpcomingFeature("ApproachableConcurrency"),
    .define("SWIFTWEB_ACTORS", .when(traits: ["Actors"])),
]

// Host and WASM builds use the same pinned Swift 6.4 development snapshot.
// This manifest still branches at evaluation time to keep host-only HTTP
// dependencies and macro tooling out of generated browser WASM graphs.
// Platform conditions only affect builds after dependency resolution, so they
// cannot provide the same graph isolation. Package generation sets these
// environment variables; ordinary consumers evaluate the full manifest.

// SWIFTWEB_DO resolves the core chain PLUS the macro toolchain and the
// SwiftWeb umbrella, for Durable Object wasm packages whose app sources use
// @Page/@ServerAction/@Actor. swift-syntax builds for the host only, so it
// does not affect the wasm binary.
let swiftWebDO = Context.environment["SWIFTWEB_DO"] == "1"
let swiftWebCoreOnly = Context.environment["SWIFTWEB_CORE_ONLY"] == "1" || swiftWebDO

let swiftHTMLDependency: Target.Dependency = .product(name: "SwiftHTML", package: "swift-html")

let swiftWebUIDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
    "SwiftWebActors",
    "SwiftWebStyle",
    "SwiftWebUITheme",
]

let swiftWebUIThemeDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
    "SwiftWebStyle",
]

let swiftWebUIRuntimeDependencies: [Target.Dependency] = [
    swiftHTMLDependency,
    .product(name: "JavaScriptKit", package: "JavaScriptKit"),
    "SwiftWebActors",
    "SwiftWebStyle",
]

let swiftWebUsesMacros = !swiftWebCoreOnly || swiftWebDO

let actorRuntimeDependency: Target.Dependency = .product(
    name: "ActorRuntime",
    package: "swift-actor-runtime",
    condition: .when(traits: ["Actors"])
)

let swiftWebActorsDependencies: [Target.Dependency] =
    [
        swiftHTMLDependency,
        actorRuntimeDependency,
    ] + (swiftWebUsesMacros ? ["SwiftWebMacros"] : [])

// The @Actor accessor macro declaration is gated behind SWIFTWEB_MACROS so that
// core-only and generated browser WASM builds compile SwiftWebActors without the
// SwiftWebMacros plugin or swift-syntax. Generated WASM packages receive client
// sources with @Actor already expanded by SwiftWebPackageGeneration.
let swiftWebActorsSwiftSettings: [SwiftSetting] =
    swiftWebSwiftSettings + (swiftWebUsesMacros ? [.define("SWIFTWEB_MACROS")] : [])

let package = Package(
    name: "swift-web",
    platforms: [
        .macOS("26.2"),
    ],
    products: swiftWebCoreOnly ? [
        .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
        .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
        .library(name: "SwiftWebUITheme", targets: ["SwiftWebUITheme"]),
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
        .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
        .library(name: "SwiftWebHost", targets: ["SwiftWebHost"]),
        .library(name: "SwiftWebBrowserRuntime", targets: ["SwiftWebBrowserRuntime"]),
        .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
    ] + (swiftWebDO ? [
        .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
    ] : []) : [
        .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
        .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
        .library(name: "SwiftWebUITheme", targets: ["SwiftWebUITheme"]),
        .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
        .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
        .library(name: "SwiftWebBrowserRuntime", targets: ["SwiftWebBrowserRuntime"]),
        .library(name: "SwiftWebHost", targets: ["SwiftWebHost"]),
        .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
        .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
        .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
        .library(name: "SwiftWebDevelopmentHooks", targets: ["SwiftWebDevelopmentHooks"]),
        .library(name: "SwiftWebWasmBuild", targets: ["SwiftWebWasmBuild"]),
        .library(name: "SwiftWebPackageGeneration", targets: ["SwiftWebPackageGeneration"]),
        .library(name: "SwiftWebDevServer", targets: ["SwiftWebDevServer"]),
        .library(name: "SwiftWebStoryboardTooling", targets: ["SwiftWebStoryboardTooling"]),
        .library(name: "SwiftWebDevelopment", targets: ["SwiftWebDevelopment"]),
        .library(name: "SwiftWebStoryboard", targets: ["SwiftWebStoryboard"]),
        .executable(name: "sweb", targets: ["SwiftWebCLI"]),
    ],
    // The Actors trait (SE-0450, default-enabled) carries the distributed
    // actor runtime: SwiftWebActors' Distributed/ActorRuntime surface,
    // ActorGroup/ActorScene lowering, and the actor security policy. Disable
    // it for page-serving-only deployments (e.g. Cloudflare Worker SSR) to
    // keep ActorRuntime and the Distributed runtime out of the binary; a
    // minimal WebActorSystem stub keeps the App/Scene API shape.
    traits: [
        .default(enabledTraits: ["Actors"]),
        .trait(name: "Actors"),
    ],
    dependencies: [
        .package(url: "https://github.com/1amageek/swift-html.git", branch: "main"),
        .package(url: "https://github.com/1amageek/JavaScriptKit.git", from: "0.57.0"),
        .package(url: "https://github.com/1amageek/swift-actor-runtime.git", exact: "0.6.0"),
        .package(url: "https://github.com/apple/swift-http-types", from: "1.0.0"),
        .package(url: "https://github.com/apple/swift-log.git", from: "1.6.0"),
    ] + (swiftWebDO ? [
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.2"),
    ] : []) + (swiftWebCoreOnly ? [] : [
        .package(url: "https://github.com/swift-server/async-http-client.git", from: "1.35.0"),
        .package(url: "https://github.com/swift-server/swift-http-server", from: "0.1.0"),
        .package(url: "https://github.com/apple/swift-http-api-proposal.git", from: "0.2.0"),
        .package(url: "https://github.com/apple/swift-nio.git", from: "2.82.0"),
        .package(url: "https://github.com/apple/swift-collections.git", from: "1.6.0"),
        .package(url: "https://github.com/apple/swift-crypto.git", from: "4.0.0"),
        .package(url: "https://github.com/apple/swift-service-context.git", from: "1.3.0"),
        .package(url: "https://github.com/swiftlang/swift-syntax.git", from: "603.0.2"),
    ]),
    targets: swiftWebCoreOnly ? [
        .target(
            name: "SwiftWebStyle",
            dependencies: [swiftHTMLDependency],
            path: "Sources/SwiftWebUI/Style",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUITheme",
            dependencies: swiftWebUIThemeDependencies,
            path: "Sources/SwiftWebUI/Theme",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebActors",
            dependencies: swiftWebActorsDependencies,
            path: "Sources/SwiftWebRuntime/Actors",
            exclude: ["README.md"],
            swiftSettings: swiftWebActorsSwiftSettings
        ),
        .target(
            name: "SwiftWebUI",
            dependencies: swiftWebUIDependencies,
            path: "Sources/SwiftWebUI/Components",
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUIRuntime",
            dependencies: swiftWebUIRuntimeDependencies,
            path: "Sources/SwiftWebBrowser/ClientRuntime",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebHost",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebBrowserRuntime",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "HTTPTypes", package: "swift-http-types"),
                "SwiftWebActors",
                "SwiftWebHost",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebBrowser/Runtime",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebCore",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebHost",
                actorRuntimeDependency,
                .product(name: "HTTPTypes", package: "swift-http-types"),
                "SwiftWebActors",
                "SwiftWebBrowserRuntime",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebRuntime/Core",
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
    ] + (swiftWebDO ? [
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
            name: "SwiftWeb",
            dependencies: [
                "SwiftWebActors",
                "SwiftWebBrowserRuntime",
                "SwiftWebCore",
                "SwiftWebMacros",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWeb",
            swiftSettings: swiftWebSwiftSettings
        ),
    ] : []) : [
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
            path: "Sources/SwiftWebUI/Style",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUITheme",
            dependencies: swiftWebUIThemeDependencies,
            path: "Sources/SwiftWebUI/Theme",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebActors",
            dependencies: swiftWebActorsDependencies,
            path: "Sources/SwiftWebRuntime/Actors",
            exclude: ["README.md"],
            swiftSettings: swiftWebActorsSwiftSettings
        ),
        .target(
            name: "SwiftWebBrowserRuntime",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "HTTPTypes", package: "swift-http-types"),
                "SwiftWebActors",
                "SwiftWebHost",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebBrowser/Runtime",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebHost",
            dependencies: [
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebCore",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebHost",
                actorRuntimeDependency,
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                "SwiftWebActors",
                "SwiftWebBrowserRuntime",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebRuntime/Core",
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWeb",
            dependencies: [
                "SwiftWebActors",
                "SwiftWebBrowserRuntime",
                "SwiftWebCore",
                "SwiftWebMacros",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWeb",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebHTTPServerHost",
            dependencies: [
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "HTTPAPIs", package: "swift-http-api-proposal"),
                .product(name: "NIOHTTPServer", package: "swift-http-server"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                "SwiftWebCore",
            ],
            path: "Sources/SwiftWebHTTPServer/Host",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUI",
            dependencies: swiftWebUIDependencies,
            path: "Sources/SwiftWebUI/Components",
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebUIRuntime",
            dependencies: swiftWebUIRuntimeDependencies,
            path: "Sources/SwiftWebBrowser/ClientRuntime",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebDevelopmentHooks",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "ServiceContextModule", package: "swift-service-context"),
                "SwiftWebCore",
            ],
            path: "Sources/SwiftWebDevelopment/Hooks",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebWasmBuild",
            dependencies: [
                .product(name: "Crypto", package: "swift-crypto"),
            ],
            path: "Sources/SwiftWebDevelopment/WasmBuild",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebPackageGeneration",
            dependencies: [
                swiftHTMLDependency,
                .product(name: "SwiftParser", package: "swift-syntax"),
                .product(name: "SwiftSyntax", package: "swift-syntax"),
                "SwiftWebDevelopmentHooks",
                "SwiftWebWasmBuild",
            ],
            path: "Sources/SwiftWebDevelopment/PackageGeneration",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebDevServer",
            dependencies: [
                "CSwiftWebSignals",
                swiftHTMLDependency,
                .product(name: "AsyncHTTPClient", package: "async-http-client"),
                .product(name: "BasicContainers", package: "swift-collections"),
                .product(name: "Crypto", package: "swift-crypto"),
                .product(name: "HTTPAPIs", package: "swift-http-api-proposal"),
                .product(name: "HTTPTypes", package: "swift-http-types"),
                .product(name: "Logging", package: "swift-log"),
                .product(name: "NIOCore", package: "swift-nio"),
                .product(name: "NIOHTTP1", package: "swift-nio"),
                .product(name: "NIOHTTPServer", package: "swift-http-server"),
                "SwiftWebCore",
                "SwiftWebDevelopmentHooks",
                "SwiftWebPackageGeneration",
                "SwiftWebWasmBuild",
            ],
            path: "Sources/SwiftWebDevelopment/DevServer",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "CSwiftWebSignals",
            path: "Sources/CSwiftWebSignals",
            publicHeadersPath: "include"
        ),
        .target(
            name: "SwiftWebStoryboardTooling",
            dependencies: [
                "SwiftWebDevelopmentHooks",
                "SwiftWebDevServer",
                "SwiftWebPackageGeneration",
            ],
            path: "Sources/SwiftWebDevelopment/StoryboardTooling",
            swiftSettings: swiftWebSwiftSettings
        ),
        .target(
            name: "SwiftWebDevelopment",
            dependencies: [
                "SwiftWebDevelopmentHooks",
                "SwiftWebDevServer",
                "SwiftWebPackageGeneration",
                "SwiftWebStoryboardTooling",
                "SwiftWebWasmBuild",
            ],
            path: "Sources/SwiftWebDevelopment/Facade",
            exclude: ["README.md"],
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
            path: "Sources/SwiftWebDevelopment/Storyboard",
            exclude: ["INFORMATION_ARCHITECTURE.md"],
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
            exclude: ["README.md"],
            swiftSettings: swiftWebSwiftSettings
        ),
        // Layout conformance harness: measures the same fixture tree in
        // SwiftUI (NSHostingView) and in SwiftWebUI's rendered CSS (WKWebView)
        // and diffs the resulting geometry. macOS-only developer tooling; not
        // a declared product.
        .executableTarget(
            name: "LayoutConformance",
            dependencies: [
                swiftHTMLDependency,
                "SwiftWebUI",
                "SwiftWebUITheme",
                "SwiftWebStyle",
            ],
            path: "Tools/LayoutConformance",
            exclude: ["report.html"],
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
            name: "SwiftWebMacroTests",
            dependencies: [
                "SwiftWebMacros",
                .product(name: "SwiftSyntaxMacrosTestSupport", package: "swift-syntax"),
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebCLITests",
            dependencies: [
                "SwiftWebCLI",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
        .testTarget(
            name: "SwiftWebTests",
            dependencies: [
                "SwiftWeb",
                "SwiftWebBrowserRuntime",
                "SwiftWebDevServer",
                "SwiftWebHTTPServerHost",
                "SwiftWebUI",
                "SwiftWebDevelopmentHooks",
                "SwiftWebDevelopment",
                "SwiftWebPackageGeneration",
                "SwiftWebStoryboardTooling",
                "SwiftWebWasmBuild",
            ],
            swiftSettings: swiftWebSwiftSettings
        ),
    ],
    swiftLanguageModes: [.v6]
)
