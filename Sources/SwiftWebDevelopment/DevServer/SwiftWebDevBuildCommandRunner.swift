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

        let cancellationController = SwiftWebDevProcessCancellationController()
        cancellationController.install(process)
        defer {
            cancellationController.clear()
            process.terminationHandler = nil
        }
        let status = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            let status = try await Self.runToCompletion(process)
            try Task.checkCancellation()
            return status
        } onCancel: {
            cancellationController.cancel()
        }
        guard status == 0 else {
            // The log stays on disk so the error can point at the full
            // compiler output; only successful runs clean it up.
            keepsFailureLog = true
            throw Self.buildFailure(
                command: commandDescription(arguments, executableURL: toolchain.swiftExecutableURL),
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

        let cancellationController = SwiftWebDevProcessCancellationController()
        cancellationController.install(process)
        defer {
            cancellationController.clear()
            process.terminationHandler = nil
        }

        let result = try await withTaskCancellationHandler {
            try Task.checkCancellation()
            // The termination handler is installed before run() so an exit can
            // never be missed; the stream buffers the status until it is awaited.
            let (statusStream, statusContinuation) = AsyncStream.makeStream(of: Int32.self)
            process.terminationHandler = { process in
                statusContinuation.yield(process.terminationStatus)
                statusContinuation.finish()
            }
            try process.run()
            if Task.isCancelled {
                cancellationController.cancel()
            }

            // Drain stdout before awaiting the exit status: an unread pipe can
            // fill and block the child.
            var data = Data()
            for try await byte in output.fileHandleForReading.bytes {
                data.append(byte)
            }

            var status: Int32 = -1
            for await exitStatus in statusStream {
                status = exitStatus
            }
            try Task.checkCancellation()
            return (data, status)
        } onCancel: {
            cancellationController.cancel()
        }

        guard result.1 == 0 else {
            keepsFailureLog = true
            throw Self.buildFailure(
                command: commandDescription(arguments, executableURL: toolchain.swiftExecutableURL),
                status: result.1,
                logURL: log.fileURL
            )
        }

        return String(decoding: result.0, as: UTF8.self)
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
            return line.trimmingCharacters(in: .whitespaces)
        }
        return nil
    }

    private static func runToCompletion(_ process: Process) async throws -> Int32 {
        try await withCheckedThrowingContinuation { continuation in
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus)
            }
            do {
                try process.run()
                if Task.isCancelled {
                    process.terminate()
                }
            } catch {
                // The process never started, so the termination handler can
                // never fire; hand the failure to the continuation instead.
                process.terminationHandler = nil
                continuation.resume(throwing: error)
            }
        }
    }

    private func commandDescription(_ arguments: [String], executableURL: URL) -> String {
        ([executableURL.path] + arguments).joined(separator: " ")
    }
}
