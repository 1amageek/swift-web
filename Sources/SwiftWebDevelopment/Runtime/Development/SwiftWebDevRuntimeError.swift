import Foundation

public enum SwiftWebDevRuntimeError: Error, Sendable, CustomStringConvertible {
    case packageManifestNotFound(URL)
    case portInUse(host: String, port: Int)
    case processFailed(command: String, status: Int32)
    case executableNotFound(String)
    case hostReadinessTimeout(host: String, port: Int, timeout: TimeInterval)
    case workerPortAllocationFailed
    case workerReadinessTimeout(host: String, port: Int, timeout: TimeInterval)
    case wasmToolchainNotFound(sdkName: String, searched: [String])
    case initialWasmBuildFailed(component: String, product: String, reason: String)

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
        case .wasmToolchainNotFound(let sdkName, let searched):
            return """
            Swift WASM toolchain was not found for \(sdkName).
            Install the matching Swift toolchain with wasm-ld, or set SWIFT_WEB_WASM_SWIFT / SWIFT_WEB_WASM_TOOLCHAIN_BIN.
            Searched:
            \(searched.joined(separator: "\n"))
            """
        case .initialWasmBuildFailed(let component, let product, let reason):
            return """
            Initial Client WASM build failed for \(component) (\(product)).
            SwiftWeb cannot start the dev server because ClientComponent actions would be rendered but non-interactive.
            Reason: \(reason)
            """
        }
    }

    public var exitCode: Int {
        switch self {
        case .packageManifestNotFound:
            return 66
        case .portInUse:
            return 69
        case .processFailed, .executableNotFound, .hostReadinessTimeout, .workerPortAllocationFailed,
             .workerReadinessTimeout, .wasmToolchainNotFound, .initialWasmBuildFailed:
            return 70
        }
    }
}
