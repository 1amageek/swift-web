#if !hasFeature(Embedded)
// Native-host wasm artifact discovery.
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

public struct SwiftPMWasmArtifactLocation: Sendable {
  public static let publishedArtifactDirectoryEnvironmentKey =
    "SWIFTWEB_PUBLISHED_WASM_ARTIFACT_DIRECTORY"
  public static let publishedArtifactGenerationEnvironmentKey =
    "SWIFTWEB_PUBLISHED_WASM_ARTIFACT_GENERATION"

  public let anchorFile: String
  public let target: String
  public let artifactName: String?
  public let configuration: String
  public let triple: String
  public let scratchDirectory: URL?

  public func url() throws -> URL {
    if let publishedDirectory = ProcessInfo.processInfo.environment[
      Self.publishedArtifactDirectoryEnvironmentKey
    ] {
      let generation = ProcessInfo.processInfo.environment[
        Self.publishedArtifactGenerationEnvironmentKey
      ] ?? "current"
      return URL(fileURLWithPath: publishedDirectory, isDirectory: true)
        .appendingPathComponent(generation, isDirectory: true)
        .appendingPathComponent("\(artifactName ?? target).wasm")
    }
    return try SwiftPMWasmArtifact.url(
      anchorFile: anchorFile,
      target: target,
      artifactName: artifactName,
      configuration: configuration,
      triple: triple,
      scratchDirectory: scratchDirectory
    )
  }
}
#endif
