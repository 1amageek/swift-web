import Foundation

public struct SwiftPMWasmArtifactLocation: Sendable {
    public let anchorFile: String
    public let target: String
    public let artifactName: String?
    public let configuration: String
    public let triple: String
    public let scratchDirectory: URL?

    public func url() throws -> URL {
        try SwiftPMWasmArtifact.url(
            anchorFile: anchorFile,
            target: target,
            artifactName: artifactName,
            configuration: configuration,
            triple: triple,
            scratchDirectory: scratchDirectory
        )
    }
}
