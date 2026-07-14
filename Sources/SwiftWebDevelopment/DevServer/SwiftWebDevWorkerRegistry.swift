import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation
import Synchronization

final class SwiftWebDevWorkerRegistry: Sendable {
    private struct State: Sendable {
        var activeTarget: SwiftWebDevWorkerTarget?
        var status = SwiftWebDevHostStatus(
            phase: "starting",
            message: "SwiftWeb dev host starting"
        )
    }

    private let state = Mutex(State())
    /// Set by the runtime once the reconciler exists; lets the host report
    /// fingerprints and staleness live instead of only at transitions
    /// (docs/DevServerReconcilerDesign.md §6.2).
    private let snapshotProvider = Mutex<(@Sendable () async -> SwiftWebDevReconcilerSnapshot)?>(nil)

    func setSnapshotProvider(
        _ provider: @escaping @Sendable () async -> SwiftWebDevReconcilerSnapshot
    ) {
        snapshotProvider.withLock { $0 = provider }
    }

    func clearSnapshotProvider() {
        snapshotProvider.withLock { $0 = nil }
    }

    func reconcilerSnapshot() async -> SwiftWebDevReconcilerSnapshot? {
        let provider = snapshotProvider.withLock { $0 }
        guard let provider else {
            return nil
        }
        return await provider()
    }

    func activate(_ target: SwiftWebDevWorkerTarget) {
        state.withLock { state in
            state.activeTarget = target
            state.status = SwiftWebDevHostStatus(
                phase: "ready",
                message: "SwiftWeb ready",
                activeWorkerURL: target.url
            )
        }
    }

    func markStarting(message: String, detail: String? = nil) {
        updateStatus(phase: "starting", message: message, detail: detail)
    }

    func markBuilding(message: String, detail: String? = nil) {
        updateStatus(phase: "building", message: message, detail: detail)
    }

    func markRestarting(message: String, detail: String? = nil) {
        updateStatus(phase: "restarting", message: message, detail: detail)
    }

    func markUnavailable(message: String, detail: String? = nil) {
        state.withLock { state in
            state.activeTarget = nil
            state.status = SwiftWebDevHostStatus(
                phase: "unavailable",
                message: message,
                detail: detail
            )
        }
    }

    func markError(message: String, detail: String? = nil) {
        updateStatus(phase: "error", message: message, detail: detail)
    }

    func activeTarget() -> SwiftWebDevWorkerTarget? {
        state.withLock { $0.activeTarget }
    }

    func status() -> SwiftWebDevHostStatus {
        state.withLock { $0.status }
    }

    private func updateStatus(phase: String, message: String, detail: String?) {
        state.withLock { state in
            state.status = SwiftWebDevHostStatus(
                phase: phase,
                message: message,
                detail: detail,
                activeWorkerURL: state.activeTarget?.url
            )
        }
    }
}
