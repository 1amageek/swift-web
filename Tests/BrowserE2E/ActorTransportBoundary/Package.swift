// swift-tools-version: 6.4
import PackageDescription

let embeddedLinkerSettings: [LinkerSetting] =
    Context.environment["SWIFTWEB_BOUNDARY_PROFILE"] == "embedded"
    ? [.linkedLibrary("swiftUnicodeDataTables", .when(platforms: [.wasi]))] : []

let package = Package(
    name: "ActorTransportBoundary",
    platforms: [.macOS(.v14)],
    dependencies: [
        .package(path: "../../..", traits: []),
        .package(url: "https://github.com/1amageek/swift-actor-system.git", exact: "0.2.0"),
        .package(url: "https://github.com/1amageek/JavaScriptKit.git", exact: "0.57.3"),
    ],
    targets: [
        .executableTarget(
            name: "ActorTransportBoundary",
            dependencies: [
                .product(name: "SwiftWebUIRuntime", package: "swift-web"),
                .product(name: "ActorSystemCore", package: "swift-actor-system"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                .product(name: "JavaScriptEventLoop", package: "JavaScriptKit"),
            ],
            linkerSettings: [.unsafeFlags([
                "-Xclang-linker", "-mexec-model=reactor",
                "-Xlinker", "--export=__main_argc_argv",
            ])] + embeddedLinkerSettings
        ),
    ]
)
