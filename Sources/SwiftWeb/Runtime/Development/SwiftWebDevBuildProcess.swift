import CryptoKit
import Foundation
import SwiftHTML

struct SwiftWebDevBuildProcess: Sendable {
    let configuration: SwiftWebDevRuntimeConfiguration

    func buildWasmRuntime(
        _ runtime: SwiftWebGeneratedWasmRuntime
    ) throws -> ClientWasmHMRManifest {
        var arguments = swiftBuildArguments()
        arguments.append("--product")
        arguments.append(runtime.productName)
        arguments.append("-c")
        arguments.append("release")
        arguments.append("--swift-sdk")
        arguments.append(wasmSwiftSDK)

        var environment = try processEnvironment()
        environment["SWIFTWEB_WASM_BUILD"] = "1"
        environment["SWIFTWEB_CORE_ONLY"] = "1"

        try runProcess(arguments: arguments, environment: environment, executableURL: URL(fileURLWithPath: "/usr/bin/xcrun"))
        let artifactURL = try SwiftPMWasmArtifact.url(
            anchorFile: configuration.packageDirectory
                .appendingPathComponent("Package.swift")
                .path,
            target: runtime.targetName
        )
        let data = try Data(contentsOf: artifactURL, options: [.mappedIfSafe])
        let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()

        return ClientWasmHMRManifest(
            componentTypeName: runtime.componentTypeName,
            bundleID: ClientBundleID(runtime.productName),
            assetPath: "\(runtime.assetPath)?v=\(hash)",
            contentHash: hash,
            stateSchemaHash: hash,
            environmentSchemaHash: hash
        )
    }

    private func swiftBuildArguments() -> [String] {
        [
            "swift",
            "build",
            "--disable-sandbox",
            "--skip-update",
            "--package-path",
            configuration.packageDirectory.path,
        ]
    }

    private func runProcess(
        arguments: [String],
        environment: [String: String],
        executableURL: URL
    ) throws {
        let process = Process()
        process.executableURL = executableURL
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = environment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            throw SwiftWebDevRuntimeError.processFailed(
                command: commandDescription(arguments, executableURL: executableURL),
                status: process.terminationStatus
            )
        }
    }

    private func processEnvironment() throws -> [String: String] {
        let moduleCacheDirectory = self.moduleCacheDirectory
        let temporaryDirectory = self.temporaryDirectory
        try FileManager.default.createDirectory(
            at: moduleCacheDirectory,
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: temporaryDirectory,
            withIntermediateDirectories: true
        )

        var environment = ProcessInfo.processInfo.environment
        environment["SWIFTPM_MODULECACHE_OVERRIDE"] = moduleCacheDirectory.path
        environment["CLANG_MODULE_CACHE_PATH"] = moduleCacheDirectory.path
        environment["TMPDIR"] = temporaryDirectory.path + "/"
        environment["TMP"] = temporaryDirectory.path
        environment["TEMP"] = temporaryDirectory.path
        if let wasmToolchainBinDirectory {
            let currentPath = environment["PATH"] ?? ""
            environment["PATH"] = "\(wasmToolchainBinDirectory.path):\(currentPath)"
        }
        return environment
    }

    private func commandDescription(_ arguments: [String], executableURL: URL) -> String {
        ([executableURL.path] + arguments).joined(separator: " ")
    }

    private var wasmSwiftSDK: String {
        ProcessInfo.processInfo.environment["SWIFT_WEB_WASM_SDK"] ?? "swift-6.3.1-RELEASE_wasm"
    }

    private var wasmToolchainBinDirectory: URL? {
        let fileManager = FileManager.default
        if let override = ProcessInfo.processInfo.environment["SWIFT_WEB_WASM_TOOLCHAIN_BIN"],
           !override.isEmpty {
            let url = URL(fileURLWithPath: override).standardizedFileURL
            if fileManager.fileExists(atPath: url.appendingPathComponent("wasm-ld").path) {
                return url
            }
        }

        let sdkName = wasmSwiftSDK
        let toolchainName: String
        if sdkName.hasSuffix("_wasm") {
            toolchainName = String(sdkName.dropLast("_wasm".count))
        } else {
            toolchainName = sdkName
        }

        let developerToolchainBin = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("Toolchains", isDirectory: true)
            .appendingPathComponent("\(toolchainName).xctoolchain", isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .standardizedFileURL
        if fileManager.fileExists(atPath: developerToolchainBin.appendingPathComponent("wasm-ld").path) {
            return developerToolchainBin
        }

        let sdkToolchainBin = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("org.swift.swiftpm", isDirectory: true)
            .appendingPathComponent("swift-sdks", isDirectory: true)
            .appendingPathComponent("\(sdkName).artifactbundle", isDirectory: true)
            .appendingPathComponent(sdkName, isDirectory: true)
            .appendingPathComponent("wasm32-unknown-wasip1", isDirectory: true)
            .appendingPathComponent("swift.xctoolchain", isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .standardizedFileURL
        if fileManager.fileExists(atPath: sdkToolchainBin.appendingPathComponent("wasm-ld").path) {
            return sdkToolchainBin
        }

        return nil
    }

    private var moduleCacheDirectory: URL {
        if let scratchDirectory = configuration.scratchDirectory {
            return scratchDirectory
                .appendingPathComponent("swiftpm-module-cache", isDirectory: true)
                .standardizedFileURL
        }

        return configuration.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("module-cache", isDirectory: true)
            .standardizedFileURL
    }

    private var temporaryDirectory: URL {
        if let scratchDirectory = configuration.scratchDirectory {
            return scratchDirectory
                .appendingPathComponent("tmp", isDirectory: true)
                .standardizedFileURL
        }

        return configuration.packageDirectory
            .appendingPathComponent(".swiftweb", isDirectory: true)
            .appendingPathComponent("tmp", isDirectory: true)
            .standardizedFileURL
    }
}
