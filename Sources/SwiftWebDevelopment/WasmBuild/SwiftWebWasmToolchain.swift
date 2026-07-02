import Foundation

public struct SwiftWebWasmToolchain: Sendable {
    public static let defaultSwiftSDKName = "swift-6.3.1-RELEASE_wasm"

    public let sdkName: String
    public let swiftExecutableURL: URL
    public let binDirectory: URL

    public static func resolve(
        sdkName: String = SwiftWebWasmToolchain.defaultSwiftSDKName
    ) throws -> SwiftWebWasmToolchain {
        let environment = ProcessInfo.processInfo.environment
        let fileManager = FileManager.default
        var searched: [String] = []

        if let override = environment["SWIFT_WEB_WASM_SWIFT"], !override.isEmpty {
            let swiftURL = URL(fileURLWithPath: override).standardizedFileURL
            searched.append(swiftURL.path)
            if fileManager.isExecutableFile(atPath: swiftURL.path) {
                return SwiftWebWasmToolchain(
                    sdkName: sdkName,
                    swiftExecutableURL: swiftURL,
                    binDirectory: swiftURL.deletingLastPathComponent()
                )
            }
        }

        if let binOverride = environment["SWIFT_WEB_WASM_TOOLCHAIN_BIN"], !binOverride.isEmpty {
            let binURL = URL(fileURLWithPath: binOverride).standardizedFileURL
            if let toolchain = toolchain(
                sdkName: sdkName,
                binDirectory: binURL,
                searched: &searched,
                fileManager: fileManager
            ) {
                return toolchain
            }
        }

        let home = fileManager.homeDirectoryForCurrentUser
        let toolchainName = toolchainName(for: sdkName)
        let developerToolchainBin = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("Toolchains", isDirectory: true)
            .appendingPathComponent("\(toolchainName).xctoolchain", isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .standardizedFileURL
        if let toolchain = toolchain(
            sdkName: sdkName,
            binDirectory: developerToolchainBin,
            searched: &searched,
            fileManager: fileManager
        ) {
            return toolchain
        }

        let swiftSDKToolchainBin = home
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
        if let toolchain = toolchain(
            sdkName: sdkName,
            binDirectory: swiftSDKToolchainBin,
            searched: &searched,
            fileManager: fileManager
        ) {
            return toolchain
        }

        throw SwiftWebWasmBuildError.wasmToolchainNotFound(
            sdkName: sdkName,
            searched: searched
        )
    }

    public func applying(to environment: [String: String]) -> [String: String] {
        var result = environment
        let currentPath = result["PATH"] ?? ""
        result["PATH"] = "\(binDirectory.path):\(currentPath)"
        return result
    }

    private static func toolchain(
        sdkName: String,
        binDirectory: URL,
        searched: inout [String],
        fileManager: FileManager
    ) -> SwiftWebWasmToolchain? {
        let swiftURL = binDirectory.appendingPathComponent("swift").standardizedFileURL
        let linkerURL = binDirectory.appendingPathComponent("wasm-ld").standardizedFileURL
        searched.append(swiftURL.path)
        searched.append(linkerURL.path)
        guard fileManager.isExecutableFile(atPath: swiftURL.path),
              fileManager.isExecutableFile(atPath: linkerURL.path)
        else {
            return nil
        }
        return SwiftWebWasmToolchain(
            sdkName: sdkName,
            swiftExecutableURL: swiftURL,
            binDirectory: binDirectory
        )
    }

    private static func toolchainName(for sdkName: String) -> String {
        if sdkName.hasSuffix("_wasm-embedded") {
            return String(sdkName.dropLast("_wasm-embedded".count))
        }
        if sdkName.hasSuffix("_wasm") {
            return String(sdkName.dropLast("_wasm".count))
        }
        return sdkName
    }
}
