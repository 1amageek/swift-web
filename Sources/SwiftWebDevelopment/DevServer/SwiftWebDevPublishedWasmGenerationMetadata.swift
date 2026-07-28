import Foundation

struct SwiftWebDevPublishedWasmGenerationMetadata: Codable, Sendable {
    static let fileName = "generation.json"

    let generationID: String
    let contentHashesByProduct: [String: String]
}

enum SwiftWebDevPublishedWasmArtifactError: Error, CustomStringConvertible {
    case invalidGenerationID(String)
    case invalidProductName(String)
    case generationUnavailable(String)
    case artifactUnavailable(product: String, generation: String)
    case artifactReadFailed(product: String, generation: String, reason: String)
    case missingContentHash(product: String)
    case contentHashMismatch(expected: String, requested: String)

    var description: String {
        switch self {
        case .invalidGenerationID(let value):
            "Invalid published WASM generation ID: \(value)"
        case .invalidProductName(let value):
            "Invalid published WASM product name: \(value)"
        case .generationUnavailable(let value):
            "Published WASM generation is no longer available: \(value)"
        case .artifactUnavailable(let product, let generation):
            "Published WASM artifact \(product) is unavailable in \(generation)"
        case .artifactReadFailed(let product, let generation, let reason):
            "Published WASM artifact \(product) could not be read in \(generation): \(reason)"
        case .missingContentHash(let product):
            "Published WASM content hash is missing for \(product)"
        case .contentHashMismatch(let expected, let requested):
            "Published WASM content hash mismatch: expected \(expected), requested \(requested)"
        }
    }
}
