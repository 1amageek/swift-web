import Foundation

struct SwiftWebWasmBuildStamp: Sendable, Codable, Equatable {
    let inputHash: String
    let artifactHash: String
}
