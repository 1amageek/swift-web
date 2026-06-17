@testable import SwiftWebDevelopment
import Foundation
import Synchronization
import Testing

@Suite
struct SwiftWebGeneratedPackageMaterializerTests {
    @Test
    func materializesGeneratedBuildPackage() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebGeneratedPackageMaterializerTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
        let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-html",
                products: [
                    .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
                ],
                targets: [
                    .target(name: "SwiftHTML"),
                ]
            )
            """,
            to: swiftHTMLPackage.appendingPathComponent("Package.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-web",
                products: [
                    .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
                    .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
                    .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
                    .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
                ],
                dependencies: [
                    .package(path: "\(swiftHTMLPackage.path)"),
                ],
                targets: [
                    .target(name: "SwiftWebActors"),
                    .target(name: "SwiftWebUI"),
                    .target(name: "SwiftWebUIRuntime"),
                    .target(name: "SwiftWeb"),
                ]
            )
            """,
            to: swiftWebPackage.appendingPathComponent("Package.swift")
        )
        try write(
            "import SwiftHTML\npublic struct Text {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Text.swift")
        )
        try write(
            "public struct WebActorSystem {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebActors/WebActorSystem.swift")
        )
        try write(
            "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUIRuntime/RuntimeEntrypoint.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "SampleApp",
                products: [
                    .library(name: "SampleApp", targets: ["SampleApp"]),
                ],
                dependencies: [
                    .package(path: "\(swiftWebPackage.path)"),
                ],
                targets: [
                    .target(name: "SampleApp"),
                ]
            )
            """,
            to: appPackage.appendingPathComponent("Package.swift")
        )
        try write("public struct SampleApp {}", to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
        try write(
            "public struct ClientSample: ClientComponent { public init() {} }",
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
        )
        try write(
            "public struct ClientBadge: ClientComponent { public init() {} }",
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientBadge.swift")
        )
        try write(
            "protocol SampleServiceProtocol {}",
            to: appPackage.appendingPathComponent("Sources/SampleApp/Services/SampleServiceProtocol.swift")
        )
        try write("struct Page {}", to: appPackage.appendingPathComponent("Sources/SampleApp/Routes/Page.swift"))
        try write("struct Service {}", to: appPackage.appendingPathComponent("Sources/SampleApp/Actions/Service.swift"))
        try write(
            """
            {
              "pins" : [
                {
                  "identity" : "javascriptkit",
                  "kind" : "remoteSourceControl",
                  "location" : "https://github.com/swiftwasm/JavaScriptKit.git",
                  "state" : {
                    "revision" : "abc",
                    "version" : "0.55.0"
                  }
                },
                {
                  "identity" : "swift-syntax",
                  "kind" : "remoteSourceControl",
                  "location" : "https://github.com/swiftlang/swift-syntax.git",
                  "state" : {
                    "revision" : "def",
                    "version" : "602.0.0"
                  }
                },
                {
                  "identity" : "vapor",
                  "kind" : "remoteSourceControl",
                  "location" : "https://github.com/vapor/vapor.git",
                  "state" : {
                    "revision" : "ghi"
                  }
                }
              ],
              "version" : 3
            }
            """,
            to: appPackage.appendingPathComponent("Package.resolved")
        )
        try write(
            "import SampleApp\n@main struct Runtime { static func main() {} }",
            to: appPackage.appendingPathComponent(".swiftweb/generated/Sources/SampleWasmRuntime/Runtime.swift")
        )
        try write("legacy", to: appPackage.appendingPathComponent(".swiftweb/generated/.materialize.lock"))

        let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: appPackage
        )
        .materialize()

        #expect(generatedPackage.appProductName == "SampleApp")
        #expect(generatedPackage.serverProductName == "app-server")
        #expect(generatedPackage.developmentServerProductName == "app-server-dev")
        #expect(generatedPackage.devProductName == "SampleApp-dev")
        #expect(generatedPackage.wasmProductNames == ["sample-app-wasm-runtime"])
        #expect(generatedPackage.packageDirectory.lastPathComponent == "server")
        #expect(generatedPackage.devPackageDirectory.lastPathComponent == "dev")
        #expect(generatedPackage.wasmPackageDirectory.lastPathComponent == "wasm")
        #expect(!FileManager.default.fileExists(
            atPath: generatedPackage.rootDirectory.appendingPathComponent(".materialize.lock").path
        ))

        let serverPackageSwift = try String(
            contentsOf: generatedPackage.packageDirectory.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let wasmPackageSwift = try String(
            contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        let devPackageSwift = try String(
            contentsOf: generatedPackage.devPackageDirectory.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        #expect(FileManager.default.fileExists(
            atPath: generatedPackage.packageDirectory.appendingPathComponent("Package.resolved").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedPackage.devPackageDirectory.appendingPathComponent("Package.resolved").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved").path
        ))
        let wasmPackageResolved = try String(
            contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved"),
            encoding: .utf8
        )
        #expect(wasmPackageResolved.contains("javascriptkit"))
        #expect(wasmPackageResolved.contains("swift-syntax"))
        #expect(!wasmPackageResolved.contains("vapor"))
        #expect(serverPackageSwift.contains(".executable(name: \"app-server\", targets: [\"AppServerLauncher\"])"))
        #expect(serverPackageSwift.contains(".package(path: \"\(appPackage.path)\""))
        #expect(!serverPackageSwift.contains(".executable(name: \"SampleApp-dev\", targets: [\"SwiftWebDevLauncher\"])"))
        #expect(!serverPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
        #expect(!serverPackageSwift.contains("SwiftWebDevLauncher"))
        #expect(!serverPackageSwift.contains("SwiftWebDevelopment"))
        #expect(!serverPackageSwift.contains("AppDevelopmentServerLauncher"))
        #expect(!serverPackageSwift.contains("sample-wasm-runtime"))
        #expect(!serverPackageSwift.contains("JavaScriptKit"))
        #expect(!serverPackageSwift.contains("swift-actor-runtime"))

        #expect(devPackageSwift.contains(".executable(name: \"SampleApp-dev\", targets: [\"SwiftWebDevLauncher\"])"))
        #expect(devPackageSwift.contains(".executable(name: \"app-server-dev\", targets: [\"AppDevelopmentServerLauncher\"])"))
        #expect(devPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
        #expect(devPackageSwift.contains(".package(path: \"\(appPackage.path)\""))
        #expect(devPackageSwift.contains(".product(name: \"SwiftWebDevelopment\", package: \"swift-web\")"))
        #expect(!devPackageSwift.contains("sample-wasm-runtime"))

        #expect(wasmPackageSwift.contains(".executable(name: \"sample-app-wasm-runtime\", targets: [\"SampleAppWasmRuntime\"])"))
        #expect(wasmPackageSwift.contains(".package(path: \"\(swiftHTMLPackage.path)\""))
        #expect(wasmPackageSwift.contains(".package(url: \"https://github.com/swiftwasm/JavaScriptKit.git\""))
        #expect(wasmPackageSwift.contains(".package(url: \"https://github.com/1amageek/swift-actor-runtime.git\", exact: \"0.5.0\")"))
        #expect(!wasmPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
        #expect(!wasmPackageSwift.contains(".package(path: \"\(appPackage.path)\""))
        #expect(!wasmPackageSwift.contains("AppServerLauncher"))
        #expect(!wasmPackageSwift.contains("SwiftWebDevLauncher"))
        #expect(!wasmPackageSwift.contains("let swiftHTMLTarget = Target.target("))
        #expect(!wasmPackageSwift.contains("path: \"Sources/SwiftHTML\""))
        #expect(wasmPackageSwift.contains(".product(name: \"SwiftHTML\", package: \"swift-html\")"))
        #expect(wasmPackageSwift.contains("let swiftWebActorsTarget = Target.target("))
        #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebActors\""))
        #expect(wasmPackageSwift.contains(".product(name: \"ActorRuntime\", package: \"swift-actor-runtime\")"))
        #expect(wasmPackageSwift.contains("let swiftWebUITarget = Target.target("))
        #expect(wasmPackageSwift.contains("let swiftWebUIRuntimeTarget = Target.target("))
        #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebUIRuntime\""))
        #expect(wasmPackageSwift.contains(".product(name: \"JavaScriptKit\", package: \"JavaScriptKit\")"))
        #expect(wasmPackageSwift.contains("""
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                "SwiftWebActors",
            ],
        """))
        #expect(wasmPackageSwift.contains("--export=swiftweb_snapshot_state"))
        #expect(wasmPackageSwift.contains("--export=swiftweb_restore_state"))
        #expect(!wasmPackageSwift.contains("exclude: [\"README.md\"]"))

        let serverSources = generatedPackage.packageDirectory.appendingPathComponent("Sources")
        let devSources = generatedPackage.devPackageDirectory.appendingPathComponent("Sources")
        let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
        #expect(FileManager.default.fileExists(
            atPath: serverSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: serverSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: devSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: devSources.appendingPathComponent("AppDevelopmentServerLauncher/ServerLauncher.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: serverSources.appendingPathComponent("SampleAppWasmRuntime/SampleAppWasmRuntime.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleApp/ClientSample.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleApp/ClientBadge.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleApp/Services/SampleServiceProtocol.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleAppWasmRuntime/SampleAppWasmRuntime.swift").path
        ))
        let wasmEntrypoint = try String(
            contentsOf: wasmSources.appendingPathComponent("SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
            encoding: .utf8
        )
        let serverLauncher = try String(
            contentsOf: serverSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift"),
            encoding: .utf8
        )
        let developmentServerLauncher = try String(
            contentsOf: devSources.appendingPathComponent("AppDevelopmentServerLauncher/ServerLauncher.swift"),
            encoding: .utf8
        )
        let developmentLauncher = try String(
            contentsOf: devSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift"),
            encoding: .utf8
        )
        #expect(serverLauncher.contains("SWIFTWEB_WASM_SCRATCH_PATH"))
        #expect(serverLauncher.contains("scratchDirectory: wasmScratchDirectory"))
        #expect(!serverLauncher.contains("SwiftWebDevelopment.install()"))
        #expect(developmentServerLauncher.contains("import SwiftWebDevelopment"))
        #expect(developmentServerLauncher.contains("SwiftWebDevelopment.install()"))
        #expect(developmentLauncher.contains("SWIFT_WEB_DEV_PRODUCT"))
        #expect(developmentLauncher.contains("app-server-dev"))
        #expect(wasmEntrypoint.contains("import SwiftWebUI"))
        #expect(wasmEntrypoint.contains("import SwiftWebUIRuntime"))
        #expect(wasmEntrypoint.contains("ClientWasmBundleRuntimeEntrypoint"))
        #expect(wasmEntrypoint.contains("ClientWasmComponentRegistration("))
        #expect(wasmEntrypoint.contains("ClientSample.self"))
        #expect(wasmEntrypoint.contains("ClientBadge.self"))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SwiftHTML").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SwiftWebActors/WebActorSystem.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SwiftWebUI/Text.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SwiftWebUI/README.md").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/README.md").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleApp/App.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleApp/Routes/Page.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleApp/Actions/Service.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: wasmSources.appendingPathComponent("SampleAppWasmRuntime/Runtime.swift").path
        ))
        #expect(!serverLauncher.contains("SwiftWebDevHotReload"))
        #expect(!serverLauncher.contains("__swiftWebDevReload"))
        #expect(!serverLauncher.contains("SWIFTWEB_DEV_TOKEN"))
    }

    @Test
    func serializesConcurrentMaterialization() async throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebGeneratedPackageConcurrentTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-web",
                products: [
                    .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
                    .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
                    .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
                    .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
                ],
                targets: [
                    .target(name: "SwiftWebActors"),
                    .target(name: "SwiftWebUI"),
                    .target(name: "SwiftWebUIRuntime"),
                    .target(name: "SwiftWeb"),
                ]
            )
            """,
            to: swiftWebPackage.appendingPathComponent("Package.swift")
        )
        try write(
            "import SwiftHTML\npublic struct Text {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Text.swift")
        )
        try write(
            "public struct WebActorSystem {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebActors/WebActorSystem.swift")
        )
        try write(
            "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUIRuntime/RuntimeEntrypoint.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "SampleApp",
                products: [
                    .library(name: "SampleApp", targets: ["SampleApp"]),
                ],
                dependencies: [
                    .package(path: "\(swiftWebPackage.path)"),
                ],
                targets: [
                    .target(name: "SampleApp"),
                ]
            )
            """,
            to: appPackage.appendingPathComponent("Package.swift")
        )
        try write("public struct SampleApp {}", to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
        try write(
            "public struct ClientSample: ClientComponent { public init() {} }",
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
        )

        let errors = Mutex<[String]>([])
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<2 {
                group.addTask {
                    do {
                        _ = try SwiftWebGeneratedPackageMaterializer(
                            appPackageDirectory: appPackage
                        )
                        .materialize()
                    } catch {
                        errors.withLock {
                            $0.append(String(describing: error))
                        }
                    }
                }
            }
        }

        let capturedErrors = errors.withLock { $0 }
        #expect(capturedErrors.isEmpty)
        #expect(!FileManager.default.fileExists(
            atPath: appPackage.appendingPathComponent(".swiftweb/generated/.materialize.lock").path
        ))

        let generatedSources = appPackage
            .appendingPathComponent(".swiftweb/generated/wasm/Sources", isDirectory: true)
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/ClientSample.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleAppWasmRuntime/SampleAppWasmRuntime.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftHTML").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftWebActors/WebActorSystem.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftWebUI/Text.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift").path
        ))
    }

    @Test
    func materializesSplitBundlesFromClientComponentContracts() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebGeneratedPackageSplitBundleTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
        let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-html",
                products: [
                    .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
                ],
                targets: [
                    .target(name: "SwiftHTML"),
                ]
            )
            """,
            to: swiftHTMLPackage.appendingPathComponent("Package.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-web",
                products: [
                    .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
                    .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
                    .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
                    .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
                ],
                dependencies: [
                    .package(path: "\(swiftHTMLPackage.path)"),
                ],
                targets: [
                    .target(name: "SwiftWebActors"),
                    .target(name: "SwiftWebUI"),
                    .target(name: "SwiftWebUIRuntime"),
                    .target(name: "SwiftWeb"),
                ]
            )
            """,
            to: swiftWebPackage.appendingPathComponent("Package.swift")
        )
        try write(
            "import SwiftHTML\npublic struct Text {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Text.swift")
        )
        try write(
            "public struct WebActorSystem {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebActors/WebActorSystem.swift")
        )
        try write(
            "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUIRuntime/RuntimeEntrypoint.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "SampleApp",
                products: [
                    .library(name: "SampleApp", targets: ["SampleApp"]),
                ],
                dependencies: [
                    .package(path: "\(swiftWebPackage.path)"),
                ],
                targets: [
                    .target(name: "SampleApp"),
                ]
            )
            """,
            to: appPackage.appendingPathComponent("Package.swift")
        )
        try write("public struct SampleApp {}", to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
        try write(
            "public struct ClientShell: ClientComponent { public init() {} }",
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientShell.swift")
        )
        try write(
            """
            public struct ClientChart: ClientComponent {
                public static let loadPolicy: LoadPolicy = .visible
                public init() {}
            }
            """,
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientChart.swift")
        )
        try write(
            """
            public struct ClientEditor: ClientComponent {
                public static let loadPolicy: LoadPolicy = .interaction
                public static let bundle: BundlePolicy = .named("editing")
                public init() {}
            }
            """,
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientEditor.swift")
        )

        let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
            appPackageDirectory: appPackage
        )
        .materialize()

        #expect(generatedPackage.wasmProductNames.contains("sample-app-wasm-runtime"))
        #expect(generatedPackage.wasmProductNames.contains("named-editing-wasm-runtime"))
        #expect(generatedPackage.wasmProductNames.count == 3)

        let wasmPackageSwift = try String(
            contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        #expect(wasmPackageSwift.contains(".executable(name: \"sample-app-wasm-runtime\", targets: [\"SampleAppWasmRuntime\"])"))
        #expect(wasmPackageSwift.contains(".executable(name: \"named-editing-wasm-runtime\", targets: [\"NamedEditingWasmRuntime\"])"))

        let serverLauncher = try String(
            contentsOf: generatedPackage.packageDirectory
                .appendingPathComponent("Sources/AppServerLauncher/ServerLauncher.swift"),
            encoding: .utf8
        )
        #expect(serverLauncher.contains("id: \"named-editing\""))
        #expect(serverLauncher.contains("componentTypeNames: [\"ClientEditor\"]"))
        #expect(serverLauncher.contains("id: \"component-"))
        #expect(serverLauncher.contains("componentTypeNames: [\"ClientChart\"]"))

        let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
        let mainEntrypoint = try String(
            contentsOf: wasmSources.appendingPathComponent("SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
            encoding: .utf8
        )
        let namedEntrypoint = try String(
            contentsOf: wasmSources.appendingPathComponent("NamedEditingWasmRuntime/NamedEditingWasmRuntime.swift"),
            encoding: .utf8
        )
        #expect(mainEntrypoint.contains("ClientShell.self"))
        #expect(!mainEntrypoint.contains("ClientChart.self"))
        #expect(!mainEntrypoint.contains("ClientEditor.self"))
        #expect(namedEntrypoint.contains("ClientEditor.self"))

        let splitEntrypoints = try FileManager.default.contentsOfDirectory(
            at: wasmSources,
            includingPropertiesForKeys: [.isDirectoryKey]
        )
        .filter { $0.lastPathComponent.hasPrefix("Component") }
        .map { directory in
            try String(
                contentsOf: directory.appendingPathComponent("\(directory.lastPathComponent).swift"),
                encoding: .utf8
            )
        }
        #expect(splitEntrypoints.count == 1)
        #expect(splitEntrypoints.first?.contains("ClientChart.self") == true)
    }

    @Test
    func repeatedMaterializationPreservesUnchangedGeneratedFiles() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebGeneratedPackageIncrementalTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
        let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-html",
                products: [
                    .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
                ],
                targets: [
                    .target(name: "SwiftHTML"),
                ]
            )
            """,
            to: swiftHTMLPackage.appendingPathComponent("Package.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "swift-web",
                products: [
                    .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
                    .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
                    .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
                    .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
                ],
                dependencies: [
                    .package(path: "\(swiftHTMLPackage.path)"),
                ],
                targets: [
                    .target(name: "SwiftWebActors"),
                    .target(name: "SwiftWebUI"),
                    .target(name: "SwiftWebUIRuntime"),
                    .target(name: "SwiftWeb"),
                ]
            )
            """,
            to: swiftWebPackage.appendingPathComponent("Package.swift")
        )
        try write(
            "import SwiftHTML\npublic struct Text {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Text.swift")
        )
        try write(
            "public struct WebActorSystem {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebActors/WebActorSystem.swift")
        )
        try write(
            "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
            to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUIRuntime/RuntimeEntrypoint.swift")
        )
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "SampleApp",
                products: [
                    .library(name: "SampleApp", targets: ["SampleApp"]),
                ],
                dependencies: [
                    .package(path: "\(swiftWebPackage.path)"),
                ],
                targets: [
                    .target(name: "SampleApp"),
                ]
            )
            """,
            to: appPackage.appendingPathComponent("Package.swift")
        )
        try write("public struct SampleApp {}", to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
        try write(
            "public struct ClientSample: ClientComponent { public init() {} }",
            to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
        )

        let materializer = SwiftWebGeneratedPackageMaterializer(appPackageDirectory: appPackage)
        let generatedPackage = try materializer.materialize()
        let packageSwift = generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift")
        let wasmEntrypoint = generatedPackage.wasmPackageDirectory
            .appendingPathComponent("Sources/SampleAppWasmRuntime/SampleAppWasmRuntime.swift")
        let copiedClientSource = generatedPackage.wasmPackageDirectory
            .appendingPathComponent("Sources/SampleApp/ClientSample.swift")
        let initialPackageDate = try #require(packageSwift.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        let initialEntrypointDate = try #require(wasmEntrypoint.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        let initialCopiedSourceDate = try #require(copiedClientSource.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)

        Thread.sleep(forTimeInterval: 1.1)
        _ = try materializer.materialize()

        let nextPackageDate = try #require(packageSwift.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        let nextEntrypointDate = try #require(wasmEntrypoint.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        let nextCopiedSourceDate = try #require(copiedClientSource.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)

        #expect(nextPackageDate == initialPackageDate)
        #expect(nextEntrypointDate == initialEntrypointDate)
        #expect(nextCopiedSourceDate == initialCopiedSourceDate)
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
