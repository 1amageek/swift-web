import Foundation

public enum SwiftWebPinnedToolchain {
    public static let snapshotTag =
        "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a"
    public static let compilerCommit = "424cae54c1a10da"

    public static func validate(swiftExecutableURL: URL) throws {
        let version = try versionOutput(from: swiftExecutableURL)
        try validate(version: version, executable: swiftExecutableURL)
    }

    public static func validate(
        swiftExecutableURL: URL,
        matchingSDKName sdkName: String
    ) throws {
        let version = try versionOutput(from: swiftExecutableURL)
        try validate(version: version, executable: swiftExecutableURL)

        let usesReleaseCompiler = version.contains("Apple Swift version 6.4 (swiftlang-6.4.0.")
        let usesReleaseSDK = sdkName.hasPrefix("swift-6.4.0-RELEASE_")
        guard usesReleaseCompiler == usesReleaseSDK else {
            throw SwiftWebWasmBuildError.swiftToolchainSDKMismatch(
                executable: swiftExecutableURL,
                sdkName: sdkName,
                actualVersion: version
            )
        }
    }

    private static func versionOutput(from swiftExecutableURL: URL) throws -> String {
        let process = Process()
        let output = Pipe()
        process.executableURL = swiftExecutableURL
        process.arguments = ["--version"]
        process.standardOutput = output
        process.standardError = output
        try process.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let version = String(decoding: data, as: UTF8.self)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard process.terminationStatus == 0 else {
            throw SwiftWebWasmBuildError.swiftToolchainVersionProbeFailed(
                executable: swiftExecutableURL,
                status: process.terminationStatus,
                output: version
            )
        }
        return version
    }

    private static func validate(version: String, executable: URL) throws {
        let usesPinnedSnapshot = version.contains(compilerCommit)
        let usesSwift64Release = version.contains(
            "Apple Swift version 6.4 (swiftlang-6.4.0."
        )
        guard usesPinnedSnapshot || usesSwift64Release else {
            throw SwiftWebWasmBuildError.swiftToolchainMismatch(
                executable: executable,
                expectedSnapshot: "Swift 6.4.0 release or \(snapshotTag)",
                expectedCompilerCommit: "Apple Swift 6.4.0 or \(compilerCommit)",
                actualVersion: version
            )
        }
    }
}
