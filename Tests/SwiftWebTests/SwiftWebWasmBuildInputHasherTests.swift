@testable import SwiftWebDevelopment
import Foundation
import Testing

@Suite
struct SwiftWebWasmBuildInputHasherTests {
    @Test
    func hashesCHeadersAndModuleMaps() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebWasmBuildInputHasherTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }
        try write(
            """
            // swift-tools-version: 6.4
            import PackageDescription
            let package = Package(name: "Runtime", targets: [.target(name: "Runtime")])
            """,
            to: root.appendingPathComponent("Package.swift")
        )
        try write("public struct Runtime {}", to: root.appendingPathComponent("Sources/Runtime/Runtime.swift"))
        try write("void swiftweb_runtime(void) {}", to: root.appendingPathComponent("Sources/Runtime/Shim.c"))
        try write("void swiftweb_runtime(void);", to: root.appendingPathComponent("Sources/Runtime/include/Shim.h"))
        try write(
            "module RuntimeShim { header \"Shim.h\" }",
            to: root.appendingPathComponent("Sources/Runtime/include/module.modulemap")
        )
        let runtime = SwiftWebGeneratedWasmRuntime(
            packageDirectory: root,
            targetName: "Runtime",
            productName: "runtime",
            componentTypeName: "Runtime",
            assetPath: "/assets/runtime.wasm"
        )

        let initial = try SwiftWebWasmBuildInputHasher.hash(
            runtime: runtime,
            sdkName: "sdk",
            swiftExecutablePath: "/swift",
            artifactProcessingSignature: "processor-v1"
        )
        try write("void swiftweb_runtime_changed(void) {}", to: root.appendingPathComponent("Sources/Runtime/Shim.c"))
        let changedC = try SwiftWebWasmBuildInputHasher.hash(
            runtime: runtime,
            sdkName: "sdk",
            swiftExecutablePath: "/swift",
            artifactProcessingSignature: "processor-v1"
        )
        try write(
            "module RuntimeShimChanged { header \"Shim.h\" }",
            to: root.appendingPathComponent("Sources/Runtime/include/module.modulemap")
        )
        let changedModuleMap = try SwiftWebWasmBuildInputHasher.hash(
            runtime: runtime,
            sdkName: "sdk",
            swiftExecutablePath: "/swift",
            artifactProcessingSignature: "processor-v1"
        )
        let changedProcessor = try SwiftWebWasmBuildInputHasher.hash(
            runtime: runtime,
            sdkName: "sdk",
            swiftExecutablePath: "/swift",
            artifactProcessingSignature: "processor-v2"
        )

        #expect(initial != changedC)
        #expect(changedC != changedModuleMap)
        #expect(changedModuleMap != changedProcessor)
    }

    private func write(_ contents: String, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }
}
