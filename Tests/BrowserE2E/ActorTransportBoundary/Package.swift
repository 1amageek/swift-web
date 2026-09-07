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
        .package(url: "https://github.com/1amageek/swift-actor-system.git", revision: "cdbca08b3a08d3cd5620ae16b5c33c372aff1ad3"),
        .package(url: "https://github.com/1amageek/JavaScriptKit.git", revision: "166dc39b6e282a0f039762381332ba6333ec809c"),
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
