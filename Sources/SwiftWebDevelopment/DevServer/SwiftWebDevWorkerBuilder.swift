import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation
import Synchronization

/// Builds the dev server executable for the reconciler
/// (docs/DevServerReconcilerDesign.md §5).
package protocol SwiftWebDevWorkerBuilding: Sendable {
    /// Prepares the build inputs and builds the dev server product, returning
    /// the executable URL. Throws `SwiftWebDevRuntimeError.workerBuildFailed`
    /// with the first compiler error line and the captured log path when the
    /// build fails.
    func build(for fingerprint: SwiftWebDevSourceFingerprint) async throws -> URL
    func cleanupArtifacts()
}

extension SwiftWebDevWorkerBuilding {
    package func cleanupArtifacts() {}
}

package final class SwiftWebDevWorkerBuilder: SwiftWebDevWorkerBuilding {
    package typealias PrepareInputs = @Sendable (SwiftWebDevSourceFingerprint) async throws -> Void

    private let configuration: SwiftWebDevRuntimeConfiguration
    private let commandRunner: any SwiftWebDevBuildCommandRunning
    /// Ensures generated packages and Client WASM artifacts match the target
    /// fingerprint before the server compiler runs. The coordinator shared
    /// with the fast path makes repeated preparation for one fingerprint a
    /// no-op (docs/DevServerReconcilerDesign.md §4.6).
    private let prepareInputs: PrepareInputs
    private let artifactRoot: URL
    /// `--show-bin-path` is configuration-derived and stable for the process
    /// lifetime — deleting `.build` does not move it — so it is resolved once
    /// instead of spawning a second SwiftPM invocation per rebuild.
    private let cachedBinPath = Mutex<URL?>(nil)

    package init(
        configuration: SwiftWebDevRuntimeConfiguration,
        commandRunner: any SwiftWebDevBuildCommandRunning,
        prepareInputs: @escaping PrepareInputs = { _ in }
    ) {
        self.configuration = configuration
        self.commandRunner = commandRunner
        self.prepareInputs = prepareInputs
        self.artifactRoot = (configuration.scratchDirectory
            ?? configuration.packageDirectory.appendingPathComponent(".swiftweb", isDirectory: true))
            .appendingPathComponent("worker-artifacts", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .standardizedFileURL
    }

    package convenience init(
        configuration: SwiftWebDevRuntimeConfiguration,
        prepareInputs: @escaping PrepareInputs = { _ in }
    ) {
        self.init(
            configuration: configuration,
            commandRunner: SwiftWebDevSwiftCommandRunner(configuration: configuration),
            prepareInputs: prepareInputs
        )
    }

    package func build(for fingerprint: SwiftWebDevSourceFingerprint) async throws -> URL {
        try await prepareInputs(fingerprint)

        var buildArguments = swiftBuildArguments()
        buildArguments.append("--quiet")
        buildArguments.append("--product")
        buildArguments.append(configuration.product)
        try await commandRunner.run(arguments: buildArguments)

        let binPath = try await resolvedBinPath()
        let executableURL = binPath.appendingPathComponent(configuration.product)
        guard FileManager.default.isExecutableFile(atPath: executableURL.path) else {
            throw SwiftWebDevRuntimeError.executableNotFound(executableURL.path)
        }
        return try snapshotExecutable(executableURL, fingerprint: fingerprint)
    }

    private func resolvedBinPath() async throws -> URL {
        if let cached = cachedBinPath.withLock({ $0 }) {
            return cached
        }

        var binPathArguments = swiftBuildArguments()
        binPathArguments.append("--quiet")
        binPathArguments.append("--show-bin-path")
        let output = try await commandRunner.capture(arguments: binPathArguments)
        guard let binPath = output
            .split(whereSeparator: \.isNewline)
            .last
            .map(String.init)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
            !binPath.isEmpty
        else {
            throw SwiftWebDevRuntimeError.executableNotFound(configuration.product)
        }

        let url = URL(fileURLWithPath: binPath, isDirectory: true)
        cachedBinPath.withLock { $0 = url }
        return url
    }

    private func swiftBuildArguments() -> [String] {
        var arguments = [
            "build",
            "--disable-sandbox",
            "--package-path",
            configuration.packageDirectory.path,
        ]

        if let scratchDirectory = configuration.scratchDirectory {
            arguments.append("--scratch-path")
            arguments.append(scratchDirectory.path)
        }

        return arguments
    }

    private func snapshotExecutable(
        _ executableURL: URL,
        fingerprint: SwiftWebDevSourceFingerprint
    ) throws -> URL {
        let directory = artifactRoot
            .appendingPathComponent(fingerprint.digest, isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = directory.appendingPathComponent(configuration.product)
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            try FileManager.default.copyItem(at: executableURL, to: destination)
        } catch {
            throw SwiftWebDevRuntimeError.artifactSnapshotFailed(
                source: executableURL.path,
                destination: destination.path,
                reason: String(describing: error)
            )
        }
        return destination
    }

    package func cleanupArtifacts() {
        guard FileManager.default.fileExists(atPath: artifactRoot.path) else {
            return
        }
        do {
            try FileManager.default.removeItem(at: artifactRoot)
        } catch {
            FileHandle.standardError.write(
                Data(
                    "Failed to remove SwiftWeb worker artifacts at \(artifactRoot.path): \(String(describing: error))\n"
                        .utf8
                )
            )
        }
    }
}
