import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

package struct SwiftWebDevHostStatus: Sendable, Codable, Equatable {
    package let phase: String
    package let message: String
    package let detail: String?
    package let activeWorkerURL: String?
    // Reconciler observability (docs/DevServerReconcilerDesign.md §6.2).
    // Optional so pre-reconciler payloads and probes keep decoding.
    package let sourceFingerprint: String?
    package let servingFingerprint: String?
    package let buildingFingerprint: String?
    package let stale: Bool?
    package let lastErrorSummary: String?

    package init(
        phase: String,
        message: String,
        detail: String? = nil,
        activeWorkerURL: String? = nil,
        sourceFingerprint: String? = nil,
        servingFingerprint: String? = nil,
        buildingFingerprint: String? = nil,
        stale: Bool? = nil,
        lastErrorSummary: String? = nil
    ) {
        self.phase = phase
        self.message = message
        self.detail = detail
        self.activeWorkerURL = activeWorkerURL
        self.sourceFingerprint = sourceFingerprint
        self.servingFingerprint = servingFingerprint
        self.buildingFingerprint = buildingFingerprint
        self.stale = stale
        self.lastErrorSummary = lastErrorSummary
    }

    package func enriched(with snapshot: SwiftWebDevReconcilerSnapshot) -> SwiftWebDevHostStatus {
        SwiftWebDevHostStatus(
            phase: phase,
            message: message,
            detail: detail,
            activeWorkerURL: activeWorkerURL,
            sourceFingerprint: snapshot.desired.short,
            servingFingerprint: snapshot.serving?.short,
            buildingFingerprint: snapshot.transitioning?.short,
            stale: snapshot.isStale,
            lastErrorSummary: snapshot.lastErrorSummary
        )
    }
}
