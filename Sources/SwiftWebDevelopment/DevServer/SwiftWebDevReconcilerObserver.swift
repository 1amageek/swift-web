import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

/// Side-effect hooks the reconciler fires on state transitions. The runtime
/// wires these to the worker registry, the HMR event log, and console logging
/// (T4); tests observe them directly. All hooks default to no-ops so callers
/// override only what they need.
package struct SwiftWebDevReconcilerObserver: Sendable {
    /// A build (or crash relaunch) toward the fingerprint began.
    package var transitionStarted: @Sendable (SwiftWebDevSourceFingerprint) -> Void = { _ in }
    /// The worker is serving; the second argument is the replaced worker, if
    /// any, already stopped.
    package var workerActivated: @Sendable (SwiftWebDevWorkerHandle, SwiftWebDevWorkerHandle?) -> Void = { _, _ in }
    /// A build or launch toward the fingerprint failed. The reconciler stays
    /// alive; the failure latches until the sources change.
    package var transitionFailed: @Sendable (SwiftWebDevSourceFingerprint, any Error) -> Void = { _, _ in }
    /// The serving worker exited unexpectedly. `willRelaunch` is false when
    /// the crash-loop breaker latched instead.
    package var workerCrashed: @Sendable (Int32, _ willRelaunch: Bool) -> Void = { _, _ in }
    /// Sources moved while a transition was in flight; another transition
    /// toward the fingerprint follows immediately.
    package var changesQueuedDuringTransition: @Sendable (SwiftWebDevSourceFingerprint) -> Void = { _ in }

    package init() {}
}
