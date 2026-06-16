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

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
