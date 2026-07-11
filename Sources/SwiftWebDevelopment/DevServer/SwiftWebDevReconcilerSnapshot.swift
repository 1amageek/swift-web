import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

/// Point-in-time view of the reconciler for status reporting
/// (docs/DevServerReconcilerDesign.md §6.2).
package struct SwiftWebDevReconcilerSnapshot: Sendable, Equatable {
    package enum Phase: String, Sendable {
        case starting
        case building
        case serving
        case failed
    }

    package let phase: Phase
    package let desired: SwiftWebDevSourceFingerprint
    package let serving: SwiftWebDevSourceFingerprint?
    package let transitioning: SwiftWebDevSourceFingerprint?
    package let lastErrorSummary: String?

    /// True when the serving worker no longer matches the sources on disk.
    package var isStale: Bool {
        serving != desired
    }

    package init(
        phase: Phase,
        desired: SwiftWebDevSourceFingerprint,
        serving: SwiftWebDevSourceFingerprint?,
        transitioning: SwiftWebDevSourceFingerprint?,
        lastErrorSummary: String?
    ) {
        self.phase = phase
        self.desired = desired
        self.serving = serving
        self.transitioning = transitioning
        self.lastErrorSummary = lastErrorSummary
    }
}
