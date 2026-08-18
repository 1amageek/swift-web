import Foundation

public struct SwiftWebWasmToolchain: Sendable {
    public static let defaultSwiftSDKName =
        "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a_wasm"
    public static let defaultEmbeddedSwiftSDKName =
        "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a_wasm-embedded"

    public let sdkName: String
    public let swiftExecutableURL: URL
    public let binDirectory: URL

    public var swiftCompilerURL: URL {
        binDirectory.appendingPathComponent("swiftc").standardizedFileURL
    }

    init(sdkName: String, swiftExecutableURL: URL, binDirectory: URL) {
        self.sdkName = sdkName
        self.swiftExecutableURL = swiftExecutableURL
        self.binDirectory = binDirectory
    }

    public static func resolve(
        sdkName: String = SwiftWebWasmToolchain.defaultSwiftSDKName,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> SwiftWebWasmToolchain {
        let supportedSDKNames = [defaultSwiftSDKName, defaultEmbeddedSwiftSDKName]
        guard supportedSDKNames.contains(sdkName) else {
            throw SwiftWebWasmBuildError.unsupportedSwiftSDKName(
                expected: supportedSDKNames,
                actual: sdkName
            )
        }
        var searched: [String] = []

        if let override = environment["SWIFT_WEB_WASM_SWIFT"], !override.isEmpty {
            let swiftURL = URL(fileURLWithPath: override).standardizedFileURL
            if let resolved = try toolchain(
                sdkName: sdkName,
                binDirectory: swiftURL.deletingLastPathComponent(),
                searched: &searched,
                fileManager: fileManager
            ), resolved.swiftExecutableURL == swiftURL {
                return resolved
            }
            throw SwiftWebWasmBuildError.wasmToolchainNotFound(
                sdkName: sdkName,
                searched: searched
            )
        }

        if let binOverride = environment["SWIFT_WEB_WASM_TOOLCHAIN_BIN"], !binOverride.isEmpty {
            let binURL = URL(fileURLWithPath: binOverride).standardizedFileURL
            if let toolchain = try toolchain(
                sdkName: sdkName,
                binDirectory: binURL,
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

        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        let toolchainName = toolchainName(for: sdkName)
        let developerToolchainBin = home
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Developer", isDirectory: true)
            .appendingPathComponent("Toolchains", isDirectory: true)
            .appendingPathComponent("\(toolchainName).xctoolchain", isDirectory: true)
            .appendingPathComponent("usr", isDirectory: true)
            .appendingPathComponent("bin", isDirectory: true)
            .standardizedFileURL
        if let toolchain = try toolchain(
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
        if let toolchain = try toolchain(
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

    public func embeddedUnicodeDataTablesLibraryURL(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        homeDirectory: URL? = nil,
        fileManager: FileManager = .default
    ) throws -> URL {
        let libraryName = "libswiftUnicodeDataTables.a"
        var candidates: [URL] = []

        if let override = environment["SWIFT_WEB_WASM_UNICODE_DATA_TABLES"],
           !override.isEmpty {
            candidates.append(URL(fileURLWithPath: override).standardizedFileURL)
        }

        candidates.append(
            binDirectory
                .deletingLastPathComponent()
                .appendingPathComponent("lib", isDirectory: true)
                .appendingPathComponent("swift", isDirectory: true)
                .appendingPathComponent("embedded", isDirectory: true)
                .appendingPathComponent("wasm32-unknown-wasip1", isDirectory: true)
                .appendingPathComponent(libraryName)
                .standardizedFileURL
        )

        let baseSDKName = sdkName.hasSuffix("-embedded")
            ? String(sdkName.dropLast("-embedded".count))
            : sdkName
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        candidates.append(
            home
                .appendingPathComponent("Library", isDirectory: true)
                .appendingPathComponent("org.swift.swiftpm", isDirectory: true)
                .appendingPathComponent("swift-sdks", isDirectory: true)
                .appendingPathComponent("\(baseSDKName).artifactbundle", isDirectory: true)
                .appendingPathComponent(baseSDKName, isDirectory: true)
                .appendingPathComponent("wasm32-unknown-wasip1", isDirectory: true)
                .appendingPathComponent("swift.xctoolchain", isDirectory: true)
                .appendingPathComponent("usr", isDirectory: true)
                .appendingPathComponent("lib", isDirectory: true)
                .appendingPathComponent("swift", isDirectory: true)
                .appendingPathComponent("embedded", isDirectory: true)
                .appendingPathComponent("wasm32-unknown-wasip1", isDirectory: true)
                .appendingPathComponent(libraryName)
                .standardizedFileURL
        )

        for candidate in candidates where fileManager.fileExists(atPath: candidate.path) {
            return candidate
        }
        throw SwiftWebWasmBuildError.requiredRuntimeLibraryNotFound(
            library: libraryName,
            sdkName: sdkName,
            searched: candidates.map { candidate in candidate.path }
        )
    }

    private static func toolchain(
        sdkName: String,
        binDirectory: URL,
        searched: inout [String],
        fileManager: FileManager
    ) throws -> SwiftWebWasmToolchain? {
        let swiftURL = binDirectory.appendingPathComponent("swift").standardizedFileURL
        let linkerURL = binDirectory.appendingPathComponent("wasm-ld").standardizedFileURL
        searched.append(swiftURL.path)
        searched.append(linkerURL.path)
        guard fileManager.isExecutableFile(atPath: swiftURL.path),
              fileManager.isExecutableFile(atPath: linkerURL.path)
        else {
            return nil
        }
        try SwiftWebPinnedToolchain.validate(swiftExecutableURL: swiftURL)
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
