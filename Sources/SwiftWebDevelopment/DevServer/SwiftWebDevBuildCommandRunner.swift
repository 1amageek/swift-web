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

        let process = Process()
        process.executableURL = toolchain.swiftExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = try environment.processEnvironment(toolchain: toolchain)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = log.handle
        process.standardError = log.handle

        let status = try await Self.runToCompletion(process)
        log.close()
        guard status == 0 else {
            // The log stays on disk so the error can point at the full
            // compiler output; only successful runs clean it up.
            throw Self.buildFailure(
                command: commandDescription(arguments, executableURL: toolchain.swiftExecutableURL),
                status: status,
                logURL: log.fileURL
            )
        }
        log.cleanup()
    }

    package func capture(arguments: [String]) async throws -> String {
        let toolchain = try SwiftWebHostSwiftToolchain.resolve(configuration: configuration)
        let output = Pipe()
        let log = try SwiftWebDevCapturedProcessLog.create(prefix: "swiftweb-dev-bin-path")

        let process = Process()
        process.executableURL = toolchain.swiftExecutableURL
        process.arguments = arguments
        process.currentDirectoryURL = configuration.packageDirectory
        process.environment = try environment.processEnvironment(toolchain: toolchain)
        process.standardInput = FileHandle.standardInput
        process.standardOutput = output
        process.standardError = log.handle

        // The termination handler is installed before run() so an exit can
        // never be missed; the stream buffers the status until it is awaited.
        let (statusStream, statusContinuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { process in
            statusContinuation.yield(process.terminationStatus)
            statusContinuation.finish()
        }
        try process.run()

        // Drain stdout before awaiting the exit status: an unread pipe can
        // fill and block the child.
        var data = Data()
        do {
            for try await byte in output.fileHandleForReading.bytes {
                data.append(byte)
            }
        } catch {
            process.terminate()
            log.close()
            log.cleanup()
            throw error
        }

        var status: Int32 = -1
        for await exitStatus in statusStream {
            status = exitStatus
        }
        log.close()
        guard status == 0 else {
            throw Self.buildFailure(
                command: commandDescription(arguments, executableURL: toolchain.swiftExecutableURL),
                status: status,
                logURL: log.fileURL
            )
        }
        log.cleanup()

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
