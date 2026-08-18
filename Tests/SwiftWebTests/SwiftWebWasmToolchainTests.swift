@testable import SwiftWebWasmBuild
import Foundation
import Testing

@Suite
struct SwiftWebWasmToolchainTests {
    @Test
    func pinnedToolchainAcceptsTheExpectedCompilerCommit() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let swift = try writeExecutable(
            output: "Swift version 6.4-dev (Swift 424cae54c1a10da)",
            at: root.appendingPathComponent("swift")
        )

        try SwiftWebPinnedToolchain.validate(swiftExecutableURL: swift)
    }

    @Test
    func pinnedToolchainRejectsAnotherSnapshot() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let swift = try writeExecutable(
            output: "Swift version 6.4-dev (Swift deadbeef)",
            at: root.appendingPathComponent("swift")
        )

        #expect(throws: SwiftWebWasmBuildError.self) {
            try SwiftWebPinnedToolchain.validate(swiftExecutableURL: swift)
        }
    }

    @Test
    func wasmOverrideRequiresTheMatchingLinkerBesideSwift() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let swift = try writeExecutable(
            output: "Swift version 6.4-dev (Swift 424cae54c1a10da)",
            at: root.appendingPathComponent("bin/swift")
        )

        #expect(throws: SwiftWebWasmBuildError.self) {
            try SwiftWebWasmToolchain.resolve(
                environment: ["SWIFT_WEB_WASM_SWIFT": swift.path],
                homeDirectory: root
            )
        }
    }

    @Test
    func wasmOverrideAcceptsThePinnedSwiftAndAdjacentLinker() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let bin = root.appendingPathComponent("bin", isDirectory: true)
        let swift = try writeExecutable(
            output: "Swift version 6.4-dev (Swift 424cae54c1a10da)",
            at: bin.appendingPathComponent("swift")
        )
        _ = try writeExecutable(
            output: "wasm-ld fixture",
            at: bin.appendingPathComponent("wasm-ld")
        )

        let toolchain = try SwiftWebWasmToolchain.resolve(
            environment: ["SWIFT_WEB_WASM_SWIFT": swift.path],
            homeDirectory: root
        )

        #expect(toolchain.swiftExecutableURL == swift)
        #expect(toolchain.binDirectory == bin.standardizedFileURL)
    }

    @Test
    func wasmToolchainRejectsAnUnpinnedSDKName() throws {
        #expect(throws: SwiftWebWasmBuildError.self) {
            try SwiftWebWasmToolchain.resolve(
                sdkName: "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2099-01-01-a_wasm",
                environment: [:]
            )
        }
    }

    @Test
    func embeddedUnicodeLibraryUsesExplicitOverride() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let override = root.appendingPathComponent("custom/libswiftUnicodeDataTables.a")
        try writeEmptyFile(at: override)
        let toolchain = makeToolchain(root: root)

        let resolved = try toolchain.embeddedUnicodeDataTablesLibraryURL(
            environment: ["SWIFT_WEB_WASM_UNICODE_DATA_TABLES": override.path],
            homeDirectory: root,
            fileManager: .default
        )

        #expect(resolved == override.standardizedFileURL)
    }

    @Test
    func embeddedUnicodeLibraryResolvesPinnedSDKLayout() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let sdkName = SwiftWebWasmToolchain.defaultEmbeddedSwiftSDKName
        let baseSDKName = String(sdkName.dropLast("-embedded".count))
        let expected = root
            .appendingPathComponent("Library/org.swift.swiftpm/swift-sdks")
            .appendingPathComponent("\(baseSDKName).artifactbundle")
            .appendingPathComponent(baseSDKName)
            .appendingPathComponent("wasm32-unknown-wasip1/swift.xctoolchain/usr/lib/swift")
            .appendingPathComponent("embedded/wasm32-unknown-wasip1/libswiftUnicodeDataTables.a")
        try writeEmptyFile(at: expected)
        let toolchain = makeToolchain(root: root)

        let resolved = try toolchain.embeddedUnicodeDataTablesLibraryURL(
            environment: [:],
            homeDirectory: root,
            fileManager: .default
        )

        #expect(resolved == expected.standardizedFileURL)
    }

    @Test
    func missingEmbeddedUnicodeLibraryIsExplicitFailure() throws {
        let root = try temporaryDirectory()
        defer { removeTemporaryDirectory(root) }
        let toolchain = makeToolchain(root: root)

        #expect(throws: SwiftWebWasmBuildError.self) {
            try toolchain.embeddedUnicodeDataTablesLibraryURL(
                environment: [:],
                homeDirectory: root,
                fileManager: .default
            )
        }
    }

    private func makeToolchain(root: URL) -> SwiftWebWasmToolchain {
        let binDirectory = root.appendingPathComponent("toolchain/usr/bin")
        return SwiftWebWasmToolchain(
            sdkName: SwiftWebWasmToolchain.defaultEmbeddedSwiftSDKName,
            swiftExecutableURL: binDirectory.appendingPathComponent("swift"),
            binDirectory: binDirectory
        )
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebWasmToolchainTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func writeEmptyFile(at url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try Data().write(to: url)
    }

    private func writeExecutable(output: String, at url: URL) throws -> URL {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try "#!/bin/sh\necho '\(output)'\n".write(
            to: url,
            atomically: true,
            encoding: .utf8
        )
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: url.path
        )
        return url.standardizedFileURL
    }

    private func removeTemporaryDirectory(_ directory: URL) {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record("Failed to remove temporary directory: \(error)")
        }
    }
}
