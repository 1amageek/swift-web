import Foundation
import SwiftWebDevelopment

struct SwiftWebLifecycleCommandRunner: Sendable {
    private let ownerProcessIdentifier: Int32

    init(ownerProcessIdentifier: Int32 = ProcessInfo.processInfo.processIdentifier) {
        self.ownerProcessIdentifier = ownerProcessIdentifier
    }

    func run(_ process: Process) async throws -> Int32 {
        try SwiftWebDevBoundedProcess.isolateProcessGroup(for: process)
        let cancellation = SwiftWebDevProcessCancellationController()
        let (statusStream, statusContinuation) = AsyncStream.makeStream(of: Int32.self)
        process.terminationHandler = { process in
            statusContinuation.yield(process.terminationStatus)
            statusContinuation.finish()
        }
        defer {
            cancellation.clear()
            process.terminationHandler = nil
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
                terminationGracePeriod: 1
            )
        } catch {
            process.terminate()
            throw SwiftWebDevRuntimeError.childProcessLifetimeMonitorLaunchFailed(
                processIdentifier: processIdentifier,
                reason: String(describing: error)
            )
        }
        cancellation.install(
            process,
            processGroupIdentifier: processIdentifier,
            childProcessLifetime: childProcessLifetime
        )

        return try await withTaskCancellationHandler {
            do {
                let status = await statusStream.first(where: { _ in true }) ?? -1
                try await cancellation.cancelAndWait(gracePeriod: 1)
                try Task.checkCancellation()
                return status
            } catch {
                try await cancellation.cancelAndWait(gracePeriod: 1)
                throw error
            }
        } onCancel: {
            cancellation.cancel()
        }
    }

}
