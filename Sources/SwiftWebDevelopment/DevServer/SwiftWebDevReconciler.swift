import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

/// The level-triggered core of the dev server: converges the running worker
/// (`actual`) toward the source tree (`desired`) instead of reacting to
/// individual change events. Wake signals — FSEvents, the periodic timer,
/// transition completion, worker exit — are only latency hints; correctness
/// comes from re-deriving everything from state on every wake
/// (docs/DevServerReconcilerDesign.md §2, §4).
///
/// Invariants:
/// - At most one transition (build+launch or crash relaunch) is in flight.
/// - A failed transition latches until the sources change; the reconciler
///   process never exits because app code does not compile.
/// - A crashed worker is relaunched from its existing executable without a
///   rebuild; three crashes inside the crash window latch as a failure.
package actor SwiftWebDevReconciler {
    private struct TransitionFailure {
        let fingerprint: SwiftWebDevSourceFingerprint
        let summary: String
    }

    private let fingerprinting: any SwiftWebDevSourceFingerprinting
    private let builder: any SwiftWebDevWorkerBuilding
    private let launcher: any SwiftWebDevWorkerLaunching
    private let observer: SwiftWebDevReconcilerObserver
    /// Fast-path hook run on every wake before convergence decisions: style
    /// patches and WASM HMR (docs/DevServerReconcilerDesign.md §4.6). Best
    /// effort — the fingerprint covers the same files, so the slow loop
    /// guarantees consistency regardless of what this does.
    private let fastPath: @Sendable (SwiftWebDevSourceFingerprint) async -> Void
    private let timerInterval: TimeInterval
    private let maxCrashCount: Int
    private let crashWindow: TimeInterval

    private let wakes: AsyncStream<Void>
    private let wakeContinuation: AsyncStream<Void>.Continuation

    private var desired: SwiftWebDevSourceFingerprint
    private var worker: SwiftWebDevWorkerHandle?
    private var transitioning: SwiftWebDevSourceFingerprint?
    private var transitionTask: Task<Void, Never>?
    private var lastFailure: TransitionFailure?
    private var crashHistory: [Date] = []
    private var isShuttingDown = false

    package init(
        fingerprinting: any SwiftWebDevSourceFingerprinting,
        builder: any SwiftWebDevWorkerBuilding,
        launcher: any SwiftWebDevWorkerLaunching,
        observer: SwiftWebDevReconcilerObserver = SwiftWebDevReconcilerObserver(),
        fastPath: @escaping @Sendable (SwiftWebDevSourceFingerprint) async -> Void = { _ in },
        timerInterval: TimeInterval = 2,
        maxCrashCount: Int = 3,
        crashWindow: TimeInterval = 60
    ) {
        self.fingerprinting = fingerprinting
        self.builder = builder
        self.launcher = launcher
        self.observer = observer
        self.fastPath = fastPath
        self.timerInterval = timerInterval
        self.maxCrashCount = maxCrashCount
        self.crashWindow = crashWindow
        self.desired = fingerprinting.fingerprint()
        // Wakes coalesce: the loop re-derives everything from state, so one
        // buffered wake is as good as ten.
        (self.wakes, self.wakeContinuation) = AsyncStream.makeStream(
            of: Void.self,
            bufferingPolicy: .bufferingNewest(1)
        )
    }

    /// Wakes the convergence loop. Safe from any context — FSEvents
    /// callbacks, termination handlers, timers.
    package nonisolated func wake() {
        wakeContinuation.yield(())
    }

    /// Ends `run()` after the in-flight convergence completes.
    package nonisolated func shutdown() {
        wakeContinuation.finish()
    }

    /// Runs until `shutdown()`. The periodic timer is the correctness
    /// backstop that makes missed change events harmless.
    package func run() async {
        let timerContinuation = wakeContinuation
        let interval = timerInterval
        let timer = Task.detached {
            while !Task.isCancelled {
                do {
                    try await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                } catch {
                    return
                }
                timerContinuation.yield(())
            }
        }
        defer {
            timer.cancel()
        }

        await converge()
        for await _ in wakes {
            await converge()
        }
    }

    /// Stops the active worker on dev-server shutdown. Call after
    /// `shutdown()` so no new transition replaces the stopped worker.
    package func stopWorkerForShutdown() async {
        isShuttingDown = true
        let activeTransition = transitionTask
        activeTransition?.cancel()
        await activeTransition?.value
        transitionTask = nil
        transitioning = nil

        let stopping = worker
        worker = nil
        await stopping?.stop()
        builder.cleanupArtifacts()
    }

    package func snapshot() -> SwiftWebDevReconcilerSnapshot {
        let phase: SwiftWebDevReconcilerSnapshot.Phase
        if lastFailure?.fingerprint == desired {
            phase = .failed
        } else if transitioning != nil {
            phase = .building
        } else if let worker, worker.isRunning {
            phase = .serving
        } else {
            phase = .starting
        }
        return SwiftWebDevReconcilerSnapshot(
            phase: phase,
            desired: desired,
            serving: worker?.isRunning == true ? worker?.fingerprint : nil,
            transitioning: transitioning,
            lastErrorSummary: lastFailure?.summary
        )
    }

    // MARK: - Convergence

    private func converge() async {
        desired = fingerprinting.fingerprint()
        await fastPath(desired)

        // Crash handling precedes the failure latch: even when the current
        // sources cannot be built, a crashed worker is still relaunched from
        // its existing executable so *something* keeps serving.
        if let worker, !worker.isRunning {
            if transitionTask != nil {
                self.worker = nil
                observer.workerUnavailableDuringTransition(worker.terminationStatus ?? -1)
                return
            }
            handleCrash(of: worker)
            return
        }

        // Single flight: the completing transition wakes the loop again.
        if transitionTask != nil || isShuttingDown {
            return
        }

        // A failed transition for the current sources can only be fixed by a
        // source change, which moves `desired` and clears this latch by
        // construction. Never hot-loop on a broken tree.
        if let lastFailure, lastFailure.fingerprint == desired {
            return
        }

        if let worker {
            if worker.fingerprint == desired {
                return
            }
            startTransition(to: desired, replacing: worker, reusingExecutable: nil)
            return
        }

        startTransition(to: desired, replacing: nil, reusingExecutable: nil)
    }

    /// Builds (or reuses an executable) and swaps the worker blue/green: the
    /// previous worker keeps serving until the replacement is ready.
    private func startTransition(
        to fingerprint: SwiftWebDevSourceFingerprint,
        replacing previous: SwiftWebDevWorkerHandle?,
        reusingExecutable: URL?
    ) {
        guard transitionTask == nil, !isShuttingDown else {
            return
        }
        transitioning = fingerprint
        observer.transitionStarted(fingerprint)

        transitionTask = Task { [weak self] in
            guard let self else {
                return
            }
            await self.runTransition(
                to: fingerprint,
                replacing: previous,
                reusingExecutable: reusingExecutable
            )
        }
    }

    private func runTransition(
        to fingerprint: SwiftWebDevSourceFingerprint,
        replacing previous: SwiftWebDevWorkerHandle?,
        reusingExecutable: URL?
    ) async {
        do {
            let executable: URL
            if let reusingExecutable {
                executable = reusingExecutable
            } else {
                executable = try await builder.build(for: fingerprint)
            }
            try Task.checkCancellation()

            let handle = try await launcher.launch(
                executable: executable,
                fingerprint: fingerprint
            )
            do {
                try await launcher.waitReady(handle)
                try Task.checkCancellation()
            } catch {
                await handle.stop()
                throw error
            }
            await completeTransition(
                activating: handle,
                replacing: previous,
                // A crash relaunch must not reset the crash window, or the
                // loop breaker could never trip: every relaunch would wipe
                // the evidence of the crash that caused it.
                resetsCrashHistory: reusingExecutable == nil
            )
        } catch {
            if !Task.isCancelled, !(error is CancellationError) {
                failTransition(toward: fingerprint, error: error)
            }
        }
        finishTransition(toward: fingerprint)
        // Sources may have moved while the transition ran; converge again.
        wake()
    }

    private func completeTransition(
        activating handle: SwiftWebDevWorkerHandle,
        replacing previous: SwiftWebDevWorkerHandle?,
        resetsCrashHistory: Bool
    ) async {
        guard !isShuttingDown else {
            await handle.stop()
            return
        }
        worker = handle
        lastFailure = nil
        if resetsCrashHistory {
            crashHistory = []
        }
        handle.onTermination { [wakeContinuation] _ in
            wakeContinuation.yield(())
        }
        if desired != handle.fingerprint {
            observer.changesQueuedDuringTransition(desired)
        }
        // Publish the ready target before draining the previous worker. The
        // public host must never route a new request to a process being stopped.
        observer.workerActivated(handle, previous)
        await previous?.stop()
    }

    private func finishTransition(toward fingerprint: SwiftWebDevSourceFingerprint) {
        guard transitioning == fingerprint else {
            return
        }
        transitioning = nil
        transitionTask = nil
    }

    private func failTransition(
        toward fingerprint: SwiftWebDevSourceFingerprint,
        error: any Error
    ) {
        lastFailure = TransitionFailure(
            fingerprint: fingerprint,
            summary: String(describing: error)
        )
        observer.transitionFailed(fingerprint, error, worker?.isRunning == true)
    }

    /// Relaunches a crashed worker from its existing executable — no rebuild.
    /// Repeated crashes inside the window latch instead, so a boot-crashing
    /// binary cannot spin the loop (docs/DevServerReconcilerDesign.md §4.5).
    private func handleCrash(of crashed: SwiftWebDevWorkerHandle) {
        let status = crashed.terminationStatus ?? -1
        worker = nil

        let now = Date()
        crashHistory.append(now)
        crashHistory.removeAll { now.timeIntervalSince($0) > crashWindow }

        guard crashHistory.count < maxCrashCount else {
            lastFailure = TransitionFailure(
                fingerprint: crashed.fingerprint,
                summary: "worker crashed \(crashHistory.count) times within \(Int(crashWindow))s (last status \(status))"
            )
            observer.workerCrashed(status, false)
            return
        }

        observer.workerCrashed(status, true)
        startTransition(
            to: crashed.fingerprint,
            replacing: nil,
            reusingExecutable: crashed.executable
        )
    }
}
