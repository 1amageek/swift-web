import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

/// Runs the host `swift` toolchain for the worker builder. Abstracted so
/// builder tests can count and script invocations without spawning SwiftPM
/// (docs/DevServerReconcilerDesign.md §5, §12 T2).
package protocol SwiftWebDevBuildCommandRunning: Sendable {
    /// Runs `swift` with the arguments; throws
    /// `SwiftWebDevRuntimeError.workerBuildFailed` on a nonzero exit.
    func run(arguments: [String]) async throws
    /// Runs `swift` with the arguments and returns captured standard output;
    /// throws `SwiftWebDevRuntimeError.workerBuildFailed` on a nonzero exit.
    func capture(arguments: [String]) async throws -> String
}

package struct SwiftWebDevSwiftCommandRunner: SwiftWebDevBuildCommandRunning {
    private let configuration: SwiftWebDevRuntimeConfiguration
    private let environment: SwiftWebDevProcessEnvironment

    package init(configuration: SwiftWebDevRuntimeConfiguration) {
        self.configuration = configuration
        self.environment = SwiftWebDevProcessEnvironment(configuration: configuration)
    }

    package func run(arguments: [String]) async throws {
        let toolchain = try SwiftWebHostSwiftToolchain.resolve(configuration: configuration)
        let log = try SwiftWebDevCapturedProcessLog.create(prefix: "swiftweb-dev-build")
        var keepsFailureLog = false
        defer {
            log.close()
            if !keepsFailureLog {
                log.cleanup()
            }
        }

        let process = Process()
        process.executableURL = toolchain.swiftExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = try environment.processEnvironment(toolchain: toolchain)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = log.handle
        process.standardError = log.handle

        let command = commandDescription(arguments, executableURL: toolchain.swiftExecutableURL)
        let status = try await SwiftWebDevBoundedProcess.run(
            process,
            timeout: configuration.buildTimeout,
            terminationGracePeriod: configuration.processTerminationGracePeriod,
            timeoutError: SwiftWebDevRuntimeError.buildTimedOut(
                command: command,
                timeout: configuration.buildTimeout
            )
        )
        try Task.checkCancellation()
        guard status == 0 else {
            // The log stays on disk so the error can point at the full
            // compiler output; only successful runs clean it up.
            keepsFailureLog = true
            throw Self.buildFailure(
                command: command,
                status: status,
                logURL: log.fileURL
            )
        }
    }

    package func capture(arguments: [String]) async throws -> String {
        let toolchain = try SwiftWebHostSwiftToolchain.resolve(configuration: configuration)
        let output = Pipe()
        let log = try SwiftWebDevCapturedProcessLog.create(prefix: "swiftweb-dev-bin-path")
        var keepsFailureLog = false
        defer {
            log.close()
            if !keepsFailureLog {
                log.cleanup()
            }
        }

        let process = Process()
        process.executableURL = toolchain.swiftExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = try environment.processEnvironment(toolchain: toolchain)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = output
        process.standardError = log.handle

        let outputHandle = output.fileHandleForReading
        let outputTask = Task.detached {
            try outputHandle.readToEnd() ?? Data()
        }
        let command = commandDescription(arguments, executableURL: toolchain.swiftExecutableURL)
        let status = try await SwiftWebDevBoundedProcess.run(
            process,
            timeout: configuration.buildTimeout,
            terminationGracePeriod: configuration.processTerminationGracePeriod,
            timeoutError: SwiftWebDevRuntimeError.buildTimedOut(
                command: command,
                timeout: configuration.buildTimeout
            )
        )
        let data = try await outputTask.value
        try Task.checkCancellation()

        guard status == 0 else {
            keepsFailureLog = true
            throw Self.buildFailure(
                command: command,
                status: status,
                logURL: log.fileURL
            )
        }

        return String(decoding: data, as: UTF8.self)
    }

    /// Builds the typed failure from the captured log: the first line
    /// containing `error:` is the summary a developer needs before opening
    /// the full log.
    package static func buildFailure(
        command: String,
        status: Int32,
        logURL: URL
    ) -> SwiftWebDevRuntimeError {
        .workerBuildFailed(
            command: command,
            status: status,
            firstErrorLine: firstErrorLine(inLogAt: logURL),
            logPath: logURL.path
        )
    }

    package static func firstErrorLine(inLogAt logURL: URL) -> String? {
        guard let data = FileManager.default.contents(atPath: logURL.path) else {
            return nil
        }
        let text = String(decoding: data, as: UTF8.self)
        for line in text.split(separator: "\n") where line.contains("error:") {
            return line.trimmingCharacters(in: Foundation.CharacterSet.whitespaces)
        }
        return nil
    }

    private func commandDescription(_ arguments: [String], executableURL: URL) -> String {
        ([executableURL.path] + arguments).joined(separator: " ")
    }
}
