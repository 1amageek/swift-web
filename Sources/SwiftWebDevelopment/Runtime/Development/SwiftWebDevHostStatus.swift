import Foundation

struct SwiftWebDevHostStatus: Sendable, Codable, Equatable {
    let phase: String
    let message: String
    let detail: String?
    let activeWorkerURL: String?

    init(
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
