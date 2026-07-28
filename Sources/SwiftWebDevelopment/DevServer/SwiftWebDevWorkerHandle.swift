import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation
import Synchronization

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

/// A running (or exited) dev worker process together with the source
/// fingerprint its executable was built from. Termination is observable so
/// the reconciler can converge on worker crashes instead of waiting for the
/// next file edit (docs/DevServerReconcilerDesign.md §4.5, §5).
package final class SwiftWebDevWorkerHandle: Sendable {
    package let target: SwiftWebDevWorkerTarget
    package let fingerprint: SwiftWebDevSourceFingerprint
    /// The built executable this worker runs. Kept so a crashed worker can be
    /// relaunched without rebuilding (docs/DevServerReconcilerDesign.md §4.5).
    package let executable: URL

    private struct State {
        var process: Process?
        var terminationStatus: Int32?
        var generationLeaseURL: URL?
        var observers: [@Sendable (Int32) -> Void] = []
    }

    private let state: Mutex<State>

    package init(
        target: SwiftWebDevWorkerTarget,
        fingerprint: SwiftWebDevSourceFingerprint,
        executable: URL,
        process: Process? = nil
    ) {
        self.target = target
        self.fingerprint = fingerprint
        self.executable = executable
        self.state = Mutex(State(process: process))
    }

    package var isRunning: Bool {
        state.withLock { $0.terminationStatus == nil }
    }

    package var terminationStatus: Int32? {
        state.withLock { $0.terminationStatus }
    }

    /// Registers an observer for process termination. An observer registered
    /// after the process already exited is invoked immediately, so a wake can
    /// never be lost to registration timing.
    package func onTermination(_ observer: @escaping @Sendable (Int32) -> Void) {
        let alreadyExited: Int32? = state.withLock { state in
            if let status = state.terminationStatus {
                return status
            }
            state.observers.append(observer)
            return nil
        }
        if let alreadyExited {
            observer(alreadyExited)
        }
    }

    /// Called exactly once by the launcher's `Process.terminationHandler`.
    package func markExited(status: Int32) {
        let resources: (observers: [@Sendable (Int32) -> Void], leaseURL: URL?) = state.withLock { state in
            guard state.terminationStatus == nil else {
                return ([], nil)
            }
            state.terminationStatus = status
            let observers = state.observers
            state.observers = []
            let leaseURL = state.generationLeaseURL
            state.generationLeaseURL = nil
            return (observers, leaseURL)
        }
        if let leaseURL = resources.leaseURL {
            do {
                try FileManager.default.removeItem(at: leaseURL)
            } catch {
                // Generation pruning also removes stale leases whose process no longer exists.
            }
        }
        for observer in resources.observers {
            observer(status)
        }
    }

    package func installGenerationLease(_ leaseURL: URL) {
        let installed = state.withLock { state in
            guard state.terminationStatus == nil else {
                return false
            }
            state.generationLeaseURL = leaseURL
            return true
        }
        guard !installed else {
            return
        }
        do {
            try FileManager.default.removeItem(at: leaseURL)
        } catch {
            // The process already exited; a future generation prune removes a stale lease.
        }
    }

    /// Graceful stop: SIGTERM, then SIGKILL after the grace period. Returns
    /// once termination has been observed (or the post-kill wait elapses).
    package func stop(gracePeriod: TimeInterval = 2) async {
        let process: Process? = state.withLock { state in
            state.terminationStatus == nil ? state.process : nil
        }
        guard let process else {
            return
        }

        process.terminate()
        if await waitForExit(timeout: gracePeriod) {
            return
        }

        #if canImport(Darwin)
        Darwin.kill(process.processIdentifier, SIGKILL)
        #elseif canImport(Glibc)
        Glibc.kill(process.processIdentifier, SIGKILL)
        #endif
        _ = await waitForExit(timeout: gracePeriod)
    }

    private func waitForExit(timeout: TimeInterval) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if !isRunning {
                return true
            }
            do {
                try await Task.sleep(nanoseconds: 50_000_000)
            } catch {
                // Cancellation: stop waiting; the caller is being torn down.
                return !isRunning
            }
        }
        return !isRunning
    }
}
