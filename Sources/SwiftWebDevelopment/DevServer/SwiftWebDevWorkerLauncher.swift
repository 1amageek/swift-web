import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

/// Launches built dev worker executables on freshly allocated loopback ports
/// and reports readiness (docs/DevServerReconcilerDesign.md §5).
package protocol SwiftWebDevWorkerLaunching: Sendable {
    func launch(
        executable: URL,
        fingerprint: SwiftWebDevSourceFingerprint
    ) async throws -> SwiftWebDevWorkerHandle
    func waitReady(_ handle: SwiftWebDevWorkerHandle) async throws
}

package final class SwiftWebDevWorkerLauncher: SwiftWebDevWorkerLaunching {
    /// The worker echoes this fingerprint on every dev response as the
    /// `X-SwiftWeb-Dev-Build` header (docs/DevServerReconcilerDesign.md §6.1).
    package static let buildFingerprintEnvironmentKey = "SWIFT_WEB_DEV_BUILD_FINGERPRINT"

    private let configuration: SwiftWebDevRuntimeConfiguration
    private let devToken: String
    private let environment: SwiftWebDevProcessEnvironment

    package init(configuration: SwiftWebDevRuntimeConfiguration, devToken: String) {
        self.configuration = configuration
        self.devToken = devToken
        self.environment = SwiftWebDevProcessEnvironment(configuration: configuration)
    }

    package func launch(
        executable: URL,
        fingerprint: SwiftWebDevSourceFingerprint
    ) async throws -> SwiftWebDevWorkerHandle {
        let port = try SwiftWebDevPortAllocator.allocateLoopbackPort()
        let target = SwiftWebDevWorkerTarget(host: "127.0.0.1", port: port)

        var workerEnvironment = try environment.processEnvironment()
        workerEnvironment["SWIFT_WEB_DEV"] = "1"
        workerEnvironment["SWIFT_WEB_DEV_RELOAD_TOKEN"] = devToken
        workerEnvironment[SwiftWebDevEventLog.environmentKey] = SwiftWebDevEventLog
            .fileURL(for: configuration)
            .path
        workerEnvironment[SwiftWebDevParentProcessMonitor.parentPIDEnvironmentKey] =
            String(ProcessInfo.processInfo.processIdentifier)
        workerEnvironment[Self.buildFingerprintEnvironmentKey] = fingerprint.digest
        if let wasmScratchDirectory = environment.wasmScratchDirectory {
            workerEnvironment["SWIFTWEB_WASM_SCRATCH_PATH"] = wasmScratchDirectory.path
        }

        let process = Process()
        process.executableURL = executable
        process.arguments = [
            "--hostname",
            target.host,
            "--port",
            String(target.port),
        ]
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = workerEnvironment
        process.standardInput = FileHandle.standardInput
        process.standardOutput = FileHandle.standardOutput
        process.standardError = FileHandle.standardError

        let handle = SwiftWebDevWorkerHandle(
            target: target,
            fingerprint: fingerprint,
            executable: executable,
            process: process
        )
        // Installed before run() so an exit can never be missed. The handler
        // is cleared after firing to break the process → handler → handle →
        // process retain cycle.
        process.terminationHandler = { process in
            handle.markExited(status: process.terminationStatus)
            process.terminationHandler = nil
        }
        try process.run()
        return handle
    }

    package func waitReady(_ handle: SwiftWebDevWorkerHandle) async throws {
        let deadline = Date().addingTimeInterval(configuration.readinessTimeout)
        while Date() < deadline {
            if let status = handle.terminationStatus {
                // The worker died before listening; reporting the exit beats
                // burning the full readiness timeout.
                throw SwiftWebDevRuntimeError.workerExitedDuringStartup(status: status)
            }
            if SwiftWebDevPortProbe.isListening(host: handle.target.host, port: handle.target.port) {
                return
            }
            do {
                try await Task.sleep(nanoseconds: 200_000_000)
            } catch {
                throw error
            }
        }
        throw SwiftWebDevRuntimeError.workerReadinessTimeout(
            host: handle.target.host,
            port: handle.target.port,
            timeout: configuration.readinessTimeout
        )
    }
}
