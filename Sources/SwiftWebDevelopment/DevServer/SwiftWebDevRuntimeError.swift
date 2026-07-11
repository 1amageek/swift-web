import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

public enum SwiftWebDevRuntimeError: Error, Sendable, CustomStringConvertible {
    case packageManifestNotFound(URL)
    case portInUse(host: String, port: Int)
    case processFailed(command: String, status: Int32)
    case executableNotFound(String)
    case hostReadinessTimeout(host: String, port: Int, timeout: TimeInterval)
    case workerPortAllocationFailed
    case workerReadinessTimeout(host: String, port: Int, timeout: TimeInterval)
    case hostSwiftToolchainNotFound(searched: [String])
    case wasmToolchainNotFound(sdkName: String, searched: [String])
    case unsupportedWasmSDK(String)
    case initialWasmBuildFailed(component: String, product: String, reason: String)
    case workerBuildFailed(command: String, status: Int32, firstErrorLine: String?, logPath: String)
    case workerExitedDuringStartup(status: Int32)

    public var description: String {
        switch self {
        case .packageManifestNotFound(let packageDirectory):
            return "Package.swift was not found in \(packageDirectory.path)"
        case .portInUse(let host, let port):
            return """
            port \(port) is already in use on \(host).
            Stop the existing SwiftWeb server or run with --port <available-port>.
            """
        case .processFailed(let command, let status):
            return "dev process failed with status \(status): \(command)"
        case .executableNotFound(let value):
            return "dev executable was not found or is not executable: \(value)"
        case .hostReadinessTimeout(let host, let port, let timeout):
            return "dev host did not become ready on \(host):\(port) within \(timeout) seconds"
        case .workerPortAllocationFailed:
            return "dev worker internal port allocation failed"
        case .workerReadinessTimeout(let host, let port, let timeout):
            return "dev worker did not become ready on \(host):\(port) within \(timeout) seconds"
        case .hostSwiftToolchainNotFound(let searched):
            return """
            Swift host toolchain was not found.
            Set SWIFT_WEB_HOST_SWIFT to a swift executable, or set SWIFT_WEB_HOST_TOOLCHAIN_BIN to a toolchain bin directory.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        case .wasmToolchainNotFound(let sdkName, let searched):
            return """
            Swift WASM toolchain was not found for \(sdkName).
            Install the matching Swift toolchain with wasm-ld, or set SWIFT_WEB_WASM_SWIFT / SWIFT_WEB_WASM_TOOLCHAIN_BIN.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        case .unsupportedWasmSDK(let sdkName):
            return """
            Unsupported Swift WASM SDK: \(sdkName).
            SwiftWeb supports the standard Swift WASM SDK only. Embedded Swift WASM is outside the public support boundary.
            """
        case .initialWasmBuildFailed(let component, let product, let reason):
            return """
            Initial Client WASM build failed for \(component) (\(product)).
            SwiftWeb cannot start the dev server because ClientComponent actions would be rendered but non-interactive.
            Reason: \(reason)
            """
        case .workerBuildFailed(let command, let status, let firstErrorLine, let logPath):
            var lines = ["dev server build failed with status \(status)"]
            if let firstErrorLine {
                lines.append(firstErrorLine)
            } else {
                lines.append(command)
            }
            lines.append("Full build log: \(logPath)")
            return lines.joined(separator: "\n")
        case .workerExitedDuringStartup(let status):
            return "dev worker exited with status \(status) before becoming ready"
        }
    }

    public var exitCode: Int {
        switch self {
        case .packageManifestNotFound:
            return 66
        case .portInUse:
            return 69
        case .processFailed, .executableNotFound, .hostReadinessTimeout, .workerPortAllocationFailed,
             .workerReadinessTimeout, .hostSwiftToolchainNotFound, .wasmToolchainNotFound,
             .unsupportedWasmSDK, .initialWasmBuildFailed, .workerBuildFailed,
             .workerExitedDuringStartup:
            return 70
        }
    }
}
