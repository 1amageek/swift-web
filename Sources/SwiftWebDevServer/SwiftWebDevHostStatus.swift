import SwiftWebDevelopmentHooks
import SwiftWebPackageGeneration
import SwiftWebWasmBuild
import Foundation

package struct SwiftWebDevHostStatus: Sendable, Codable, Equatable {
    package let phase: String
    package let message: String
    package let detail: String?
    package let activeWorkerURL: String?

    package init(
        phase: String,
        message: String,
        detail: String? = nil,
        activeWorkerURL: String? = nil
    ) {
        self.phase = phase
        self.message = message
        self.detail = detail
        self.activeWorkerURL = activeWorkerURL
    }
}
