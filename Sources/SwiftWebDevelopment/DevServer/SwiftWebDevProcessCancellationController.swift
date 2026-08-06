import Foundation
import Synchronization

/// Bridges structured task cancellation to a complete Foundation child tree.
package final class SwiftWebDevProcessCancellationController: Sendable {
    private struct State {
        var process: Process?
        var processGroupIdentifier: Int32?
        var childProcessLifetime: SwiftWebChildProcessLifetime?
        var isCancellationRequested = false
    }

    private let state = Mutex(State())

    package init() {}

    package func install(
        _ process: Process,
        processGroupIdentifier: Int32,
        childProcessLifetime: SwiftWebChildProcessLifetime
    ) {
        let shouldTerminate = state.withLock { state in
            state.process = process
            state.processGroupIdentifier = processGroupIdentifier
            state.childProcessLifetime = childProcessLifetime
            return state.isCancellationRequested
        }
        if shouldTerminate {
            childProcessLifetime.requestTermination()
        }
    }

    package func clear() {
        let childProcessLifetime = state.withLock { state in
            let lifetime = state.childProcessLifetime
            state.process = nil
            state.processGroupIdentifier = nil
            state.childProcessLifetime = nil
            return lifetime
        }
        childProcessLifetime?.clear()
    }

    package func cancel() {
        let snapshot = state.withLock { state in
            state.isCancellationRequested = true
            return (state.processGroupIdentifier, state.childProcessLifetime)
        }
        if let childProcessLifetime = snapshot.1 {
            childProcessLifetime.requestTermination()
        } else if let processGroupIdentifier = snapshot.0 {
            signalProcessGroup(processGroupIdentifier, signal: SIGTERM)
        }
    }

    package func cancelAndWait(gracePeriod: TimeInterval) async throws {
        let snapshot = state.withLock {
            ($0.processGroupIdentifier, $0.childProcessLifetime)
        }
        guard let processGroupIdentifier = snapshot.0 else {
            return
        }

        if let childProcessLifetime = snapshot.1 {
            childProcessLifetime.requestTermination()
            guard await childProcessLifetime.waitUntilTerminated(
                timeout: max(1, gracePeriod + 1)
            ) else {
                signalProcessGroup(processGroupIdentifier, signal: SIGKILL)
                throw SwiftWebDevRuntimeError.processTreeTerminationTimedOut(
                    processIdentifier: processGroupIdentifier
                )
            }
        } else {
            signalProcessGroup(processGroupIdentifier, signal: SIGTERM)
        }

        if await Self.waitForProcessGroupExit(
            processGroupIdentifier,
            timeout: gracePeriod
        ) {
            return
        }
        signalProcessGroup(processGroupIdentifier, signal: SIGKILL)
        guard await Self.waitForProcessGroupExit(
            processGroupIdentifier,
            timeout: max(1, gracePeriod + 1)
        ) else {
            throw SwiftWebDevRuntimeError.processGroupTerminationTimedOut(
                processGroupIdentifier: processGroupIdentifier
            )
        }
    }

    private func signalProcessGroup(_ processGroupIdentifier: Int32, signal: Int32) {
        if kill(-processGroupIdentifier, signal) != 0, errno != ESRCH {
            let processIdentifier = state.withLock { $0.process?.processIdentifier }
            if let processIdentifier {
                _ = kill(processIdentifier, signal)
            }
        }
    }

    private static func processGroupExists(_ processGroupIdentifier: Int32) -> Bool {
        if kill(-processGroupIdentifier, 0) == 0 {
            return true
        }
        return errno == EPERM
    }

    private static func waitForProcessGroupExit(
        _ processGroupIdentifier: Int32,
        timeout: TimeInterval
    ) async -> Bool {
        await Task.detached {
            let clock = ContinuousClock()
            let milliseconds = Int64(max(0, timeout) * 1_000)
            let deadline = clock.now.advanced(by: .milliseconds(milliseconds))
            while processGroupExists(processGroupIdentifier), clock.now < deadline {
                do {
                    try await Task.sleep(for: .milliseconds(10))
                } catch {
                    // Detached polling is not cancelled by the caller.
                }
            }
            return !processGroupExists(processGroupIdentifier)
        }.value
    }
}
