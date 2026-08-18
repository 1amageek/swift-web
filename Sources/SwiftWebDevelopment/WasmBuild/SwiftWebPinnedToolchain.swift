import Foundation

public enum SwiftWebPinnedToolchain {
    public static let snapshotTag =
        "swift-6.4.x-DEVELOPMENT-SNAPSHOT-2026-08-14-a"
    public static let compilerCommit = "424cae54c1a10da"

    public static func validate(swiftExecutableURL: URL) throws {
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
        guard version.contains(compilerCommit) else {
            throw SwiftWebWasmBuildError.swiftToolchainMismatch(
                executable: swiftExecutableURL,
                expectedSnapshot: snapshotTag,
                expectedCompilerCommit: compilerCommit,
                actualVersion: version
            )
        }
    }
}
