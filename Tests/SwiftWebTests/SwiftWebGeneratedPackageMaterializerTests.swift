@testable import SwiftWeb
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
        try write(
            "protocol SampleServiceProtocol {}",
            to: appPackage.appendingPathComponent("Sources/SampleApp/Services/SampleServiceProtocol.swift")
        )
        try write("struct Page {}", to: appPackage.appendingPathComponent("Sources/SampleApp/Routes/Page.swift"))
        try write("struct Service {}", to: appPackage.appendingPathComponent("Sources/SampleApp/Actions/Service.swift"))
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
        #expect(generatedPackage.devProductName == "SampleApp")
        #expect(generatedPackage.wasmProductNames == ["sample-wasm-runtime"])
        #expect(!FileManager.default.fileExists(
            atPath: generatedPackage.packageDirectory.appendingPathComponent(".materialize.lock").path
        ))

        let packageSwift = try String(
            contentsOf: generatedPackage.packageDirectory.appendingPathComponent("Package.swift"),
            encoding: .utf8
        )
        #expect(packageSwift.contains(".executable(name: \"SampleApp\", targets: [\"SwiftWebDevLauncher\"])"))
        #expect(packageSwift.contains(".executable(name: \"app-server\", targets: [\"AppServerLauncher\"])"))
        #expect(packageSwift.contains(".executable(name: \"sample-wasm-runtime\", targets: [\"SampleWasmRuntime\"])"))
        #expect(packageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
        #expect(packageSwift.contains(".package(url: \"https://github.com/1amageek/swift-html.git\", from: \"0.2.0\")"))
        #expect(packageSwift.contains(".package(url: \"https://github.com/swiftwasm/JavaScriptKit.git\""))
        #expect(packageSwift.contains(".package(url: \"https://github.com/1amageek/swift-actor-runtime.git\", exact: \"0.5.0\")"))
        #expect(!packageSwift.contains("let swiftHTMLTarget = Target.target("))
        #expect(!packageSwift.contains("path: \"Sources/SwiftHTML\""))
        #expect(packageSwift.contains(".product(name: \"SwiftHTML\", package: \"swift-html\")"))
        #expect(packageSwift.contains("let swiftWebActorsTarget = Target.target("))
        #expect(packageSwift.contains("path: \"Sources/SwiftWebActors\""))
        #expect(packageSwift.contains(".product(name: \"ActorRuntime\", package: \"swift-actor-runtime\")"))
        #expect(packageSwift.contains("let swiftWebUITarget = Target.target("))
        #expect(packageSwift.contains("let swiftWebUIRuntimeTarget = Target.target("))
        #expect(packageSwift.contains("path: \"Sources/SwiftWebUIRuntime\""))
        #expect(packageSwift.contains(".product(name: \"JavaScriptKit\", package: \"JavaScriptKit\")"))
        #expect(packageSwift.contains("""
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                .product(name: "SwiftHTML", package: "swift-html"),
                .product(name: "JavaScriptKit", package: "JavaScriptKit"),
                "SwiftWebActors",
            ],
        """))
        #expect(packageSwift.contains("--export=swiftweb_snapshot_state"))
        #expect(packageSwift.contains("--export=swiftweb_restore_state"))
        #expect(!packageSwift.contains("exclude: [\"README.md\"]"))

        let generatedSources = generatedPackage.packageDirectory.appendingPathComponent("Sources")
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/ClientSample.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/Services/SampleServiceProtocol.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleWasmRuntime/SampleWasmRuntime.swift").path
        ))
        let wasmEntrypoint = try String(
            contentsOf: generatedSources.appendingPathComponent("SampleWasmRuntime/SampleWasmRuntime.swift"),
            encoding: .utf8
        )
        #expect(wasmEntrypoint.contains("import SwiftWebUI"))
        #expect(wasmEntrypoint.contains("import SwiftWebUIRuntime"))
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
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftWebUI/README.md").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SwiftWebUIRuntime/README.md").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/App.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/Routes/Page.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/Actions/Service.swift").path
        ))
        #expect(!FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleWasmRuntime/Runtime.swift").path
        ))
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
            .appendingPathComponent(".swiftweb/generated/Sources", isDirectory: true)
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleApp/ClientSample.swift").path
        ))
        #expect(FileManager.default.fileExists(
            atPath: generatedSources.appendingPathComponent("SampleWasmRuntime/SampleWasmRuntime.swift").path
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

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
