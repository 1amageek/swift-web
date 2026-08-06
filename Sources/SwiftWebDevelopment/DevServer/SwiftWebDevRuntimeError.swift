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
    case buildTimedOut(command: String, timeout: TimeInterval)
    case clientRuntimeTransactionFailed(reason: String)
    case workerExitedDuringStartup(status: Int32)
    case artifactSnapshotFailed(source: String, destination: String, reason: String)
    case signalHandlerInstallationFailed(code: Int32)
    case processGroupIsolationFailed(processIdentifier: Int32, actualProcessGroup: Int32)
    case childProcessLifetimeMonitorLaunchFailed(processIdentifier: Int32, reason: String)
    case processTreeTerminationTimedOut(processIdentifier: Int32)
    case processGroupTerminationTimedOut(processGroupIdentifier: Int32)

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
        case .buildTimedOut(let command, let timeout):
            return "dev build timed out after \(timeout) seconds: \(command)"
        case .clientRuntimeTransactionFailed(let reason):
            return "Client WASM transaction failed: \(reason)"
        case .workerExitedDuringStartup(let status):
            return "dev worker exited with status \(status) before becoming ready"
        case .artifactSnapshotFailed(let source, let destination, let reason):
            return "dev worker artifact snapshot failed from \(source) to \(destination): \(reason)"
        case .signalHandlerInstallationFailed(let code):
            return "dev termination signal handler installation failed with errno \(code)"
        case .processGroupIsolationFailed(let processIdentifier, let actualProcessGroup):
            return "dev process \(processIdentifier) was not isolated as its own process group (actual pgid \(actualProcessGroup))"
        case .childProcessLifetimeMonitorLaunchFailed(let processIdentifier, let reason):
            return "dev process \(processIdentifier) lifetime monitor failed to start: \(reason)"
        case .processTreeTerminationTimedOut(let processIdentifier):
            return "dev process tree rooted at \(processIdentifier) did not terminate after SIGKILL"
        case .processGroupTerminationTimedOut(let processGroupIdentifier):
            return "dev process group \(processGroupIdentifier) did not terminate after SIGKILL"
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
             .buildTimedOut, .clientRuntimeTransactionFailed,
             .workerExitedDuringStartup, .artifactSnapshotFailed,
             .signalHandlerInstallationFailed, .processGroupIsolationFailed,
             .childProcessLifetimeMonitorLaunchFailed, .processTreeTerminationTimedOut,
             .processGroupTerminationTimedOut:
            return 70
        }
    }
}
