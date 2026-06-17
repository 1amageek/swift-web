@testable import SwiftWeb
import Foundation
import Testing

@Suite
struct SwiftPMWasmArtifactTests {
    @Test
    func findsArtifactInLocalDependencyBuildRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPMWasmArtifactTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let appPackage = root.appendingPathComponent("CounterApp", isDirectory: true)
        let dependencyPackage = root.appendingPathComponent("swift-web", isDirectory: true)
        let appSource = appPackage.appendingPathComponent("Sources/CounterApp/App.swift")
        let wasmArtifact = dependencyPackage
            .appendingPathComponent(".build/wasm32-unknown-wasip1/release/counter-wasm-runtime.wasm")

        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(
                name: "CounterApp",
                dependencies: [
                    .package(path: "../swift-web"),
                ],
                targets: [
                    .target(name: "CounterApp"),
                ]
            )
            """,
            to: appPackage.appendingPathComponent("Package.swift")
        )
        try write("public struct CounterApp {}", to: appSource)
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(name: "swift-web")
            """,
            to: dependencyPackage.appendingPathComponent("Package.swift")
        )
        try write("wasm", to: wasmArtifact)

        let resolvedURL = try SwiftPMWasmArtifact.url(
            anchorFile: appSource.path,
            target: "CounterWasmRuntime"
        )

        #expect(resolvedURL.standardizedFileURL == wasmArtifact.standardizedFileURL)
    }

    @Test
    func findsArtifactInExplicitScratchRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPMWasmArtifactTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let package = root.appendingPathComponent("WasmPackage", isDirectory: true)
        let source = package.appendingPathComponent("Sources/Runtime/Runtime.swift")
        let scratch = root.appendingPathComponent("scratch/wasm", isDirectory: true)
        let wasmArtifact = scratch
            .appendingPathComponent("wasm32-unknown-wasip1/release/counter-wasm-runtime.wasm")

        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(name: "WasmPackage")
            """,
            to: package.appendingPathComponent("Package.swift")
        )
        try write("public struct Runtime {}", to: source)
        try write("wasm", to: wasmArtifact)

        let resolvedURL = try SwiftPMWasmArtifact.url(
            anchorFile: source.path,
            target: "CounterWasmRuntime",
            scratchDirectory: scratch
        )

        #expect(resolvedURL.standardizedFileURL == wasmArtifact.standardizedFileURL)
    }

    @Test
    func findsArtifactInGeneratedWasmConventionalScratchRoot() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftPMWasmArtifactTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let generated = root.appendingPathComponent(".swiftweb/generated", isDirectory: true)
        let wasmPackage = generated.appendingPathComponent("wasm", isDirectory: true)
        let source = wasmPackage.appendingPathComponent("Sources/Runtime/Runtime.swift")
        let wasmArtifact = generated
            .appendingPathComponent(".build/wasm/wasm32-unknown-wasip1/release/counter-wasm-runtime.wasm")

        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription

            let package = Package(name: "GeneratedWasm")
            """,
            to: wasmPackage.appendingPathComponent("Package.swift")
        )
        try write("public struct Runtime {}", to: source)
        try write("wasm", to: wasmArtifact)

        let resolvedURL = try SwiftPMWasmArtifact.url(
            anchorFile: source.path,
            target: "CounterWasmRuntime"
        )

        #expect(resolvedURL.standardizedFileURL == wasmArtifact.standardizedFileURL)
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
