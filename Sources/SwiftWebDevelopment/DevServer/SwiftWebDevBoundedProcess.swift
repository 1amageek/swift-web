import Foundation

package enum SwiftWebDevBoundedProcess {
    package static func run(
        _ process: Process,
        timeout: TimeInterval?,
        terminationGracePeriod: TimeInterval,
        ownerProcessIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier,
        timeoutError: @escaping @Sendable (TimeInterval) -> any Error
    ) async throws -> Int32 {
        try isolateProcessGroup(for: process)
        let cancellationController = SwiftWebDevProcessCancellationController()
        defer {
            cancellationController.clear()
            process.terminationHandler = nil
        }

        let (statusStream, statusContinuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { process in
            statusContinuation.yield(process.terminationStatus)
            statusContinuation.finish()
        }
        try process.run()
        let processIdentifier = process.processIdentifier
        let actualProcessGroup = getpgid(processIdentifier)
        guard actualProcessGroup == processIdentifier else {
            process.terminate()
            throw SwiftWebDevRuntimeError.processGroupIsolationFailed(
                processIdentifier: processIdentifier,
                actualProcessGroup: actualProcessGroup
            )
        }
        let childProcessLifetime: SwiftWebChildProcessLifetime
        do {
            childProcessLifetime = try SwiftWebChildProcessLifetime(
                commandProcessIdentifier: processIdentifier,
                ownerProcessIdentifier: ownerProcessIdentifier,
                terminationGracePeriod: terminationGracePeriod
            )
        } catch {
            process.terminate()
            throw SwiftWebDevRuntimeError.childProcessLifetimeMonitorLaunchFailed(
                processIdentifier: processIdentifier,
                reason: String(describing: error)
            )
        }
        cancellationController.install(
            process,
            processGroupIdentifier: processIdentifier,
            childProcessLifetime: childProcessLifetime
        )

        return try await withTaskCancellationHandler {
            do {
                let status: Int32 = try await withThrowingTaskGroup(of: Int32.self) { group in
                    group.addTask {
                        for await status in statusStream {
                            return status
                        }
                        return -1
                    }
                    if let timeout {
                        group.addTask {
                            let milliseconds = Int64(max(0, timeout) * 1_000)
                            try await Task.sleep(for: .milliseconds(milliseconds))
                            throw timeoutError(timeout)
                        }
                    }
                    guard let status = try await group.next() else {
                        return -1
                    }
                    group.cancelAll()
                    return status
                }
                // AsyncStream iteration may finish with no value when its task
                // is cancelled. Preserve parent cancellation as an error so the
                // catch path keeps the controller installed through TERM/KILL.
                try Task.checkCancellation()
                // The root process may exit after spawning a descendant that
                // inherited its pipes. Drain the isolated group before the
                // caller waits for pipe EOF or releases operation ownership.
                try await cancellationController.cancelAndWait(
                    gracePeriod: terminationGracePeriod
                )
                // Cancellation can arrive while the uncancelled group drain
                // is in progress. Preserve it after cleanup completes.
                try Task.checkCancellation()
                return status
            } catch {
                try await cancellationController.cancelAndWait(
                    gracePeriod: terminationGracePeriod
                )
                throw error
            }
        } onCancel: {
            cancellationController.cancel()
        }
    }

    package static func isolateProcessGroup(for process: Process) throws {
        guard let executableURL = process.executableURL else {
            throw CocoaError(.executableNotLoadable)
        }
        let originalArguments = process.arguments ?? []
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = [
            "-c",
            "set -m; exec \"$@\"",
            "swiftweb-process-group",
            executableURL.path,
        ] + originalArguments
    }
}
