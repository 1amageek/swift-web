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
    func build() async throws -> URL
}

package final class SwiftWebDevWorkerBuilder: SwiftWebDevWorkerBuilding {
    package typealias PrepareInputs = @Sendable () async throws -> Void

    private let configuration: SwiftWebDevRuntimeConfiguration
    private let commandRunner: any SwiftWebDevBuildCommandRunning
    /// Regenerates the build inputs (package materialization) before the
    /// compiler runs. Injected so materialization cost is paid only on the
    /// build path, never on css-only change wakes
    /// (docs/DevServerReconcilerDesign.md §4.6).
    private let prepareInputs: PrepareInputs
    /// `--show-bin-path` is configuration-derived and stable for the process
    /// lifetime — deleting `.build` does not move it — so it is resolved once
    /// instead of spawning a second SwiftPM invocation per rebuild.
    private let cachedBinPath = Mutex<URL?>(nil)

    package init(
        configuration: SwiftWebDevRuntimeConfiguration,
        commandRunner: any SwiftWebDevBuildCommandRunning,
        prepareInputs: @escaping PrepareInputs = {}
    ) {
        self.configuration = configuration
        self.commandRunner = commandRunner
        self.prepareInputs = prepareInputs
    }

    package convenience init(
        configuration: SwiftWebDevRuntimeConfiguration,
        prepareInputs: @escaping PrepareInputs = {}
    ) {
        self.init(
            configuration: configuration,
            commandRunner: SwiftWebDevSwiftCommandRunner(configuration: configuration),
            prepareInputs: prepareInputs
        )
    }

    package func build() async throws -> URL {
        try await prepareInputs()

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
        return executableURL
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
}
