import Foundation

public enum SwiftWebWasmBuildError: Error, Sendable, CustomStringConvertible {
    case wasmToolchainNotFound(sdkName: String, searched: [String])
    case swiftSDKConfigurationNotFound(sdkName: String, searched: [String])
    case invalidSwiftSDKConfiguration(sdkName: String, path: String, reason: String)
    case requiredRuntimeLibraryNotFound(
        library: String,
        sdkName: String,
        searched: [String]
    )
    case unsupportedSwiftSDKName(expected: [String], actual: String)
    case swiftToolchainVersionProbeFailed(
        executable: URL,
        status: Int32,
        output: String
    )
    case swiftToolchainMismatch(
        executable: URL,
        expectedSnapshot: String,
        expectedCompilerCommit: String,
        actualVersion: String
    )

    public var description: String {
        switch self {
        case .wasmToolchainNotFound(let sdkName, let searched):
            return """
            Swift WASM toolchain was not found for \(sdkName).
            Install the matching Swift toolchain with wasm-ld, or set SWIFT_WEB_WASM_SWIFT / SWIFT_WEB_WASM_TOOLCHAIN_BIN.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        case .swiftSDKConfigurationNotFound(let sdkName, let searched):
            return """
            Swift SDK configuration was not found for \(sdkName).
            Install the pinned Swift SDK with `swift sdk install`.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        case .invalidSwiftSDKConfiguration(let sdkName, let path, let reason):
            return "Swift SDK configuration for \(sdkName) is invalid at \(path): \(reason)"
        case .requiredRuntimeLibraryNotFound(let library, let sdkName, let searched):
            return """
            Required runtime library \(library) was not found for \(sdkName).
            Install the matching Swift SDK or set SWIFT_WEB_WASM_UNICODE_DATA_TABLES.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        case .unsupportedSwiftSDKName(let expected, let actual):
            return "Swift SDK \(actual) does not match the pinned SDKs: \(expected.joined(separator: ", "))"
        case .swiftToolchainVersionProbeFailed(let executable, let status, let output):
            return "Swift toolchain version probe failed for \(executable.path) with status \(status): \(output)"
        case .swiftToolchainMismatch(
            let executable,
            let expectedSnapshot,
            let expectedCompilerCommit,
            let actualVersion
        ):
            return "Swift toolchain \(executable.path) does not match \(expectedSnapshot) (Swift \(expectedCompilerCommit)): \(actualVersion)"
        }
    }
}
