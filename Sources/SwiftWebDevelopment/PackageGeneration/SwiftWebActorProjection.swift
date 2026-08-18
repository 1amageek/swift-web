import ActorSystemGeneration
import Foundation

struct SwiftWebActorProjection: Sendable {
  enum GeneratedTargetRole {
    case rootApplication
    case actorDependency
  }

  let manifest: ActorGeneratedManifest
  let generatedDirectory: URL
  let targetEnvironment: ActorGenerationTargetEnvironment

  init(
    manifest: ActorGeneratedManifest,
    generatedDirectory: URL,
    targetEnvironment: ActorGenerationTargetEnvironment
  ) throws {
    try manifest.verifyGeneratedFiles(in: generatedDirectory)
    self.manifest = manifest
    self.generatedDirectory = generatedDirectory.standardizedFileURL
    self.targetEnvironment = targetEnvironment
  }

  func project(relativePath: String, data: Data) throws -> Data {
    guard let input = manifest.inputSources.first(where: {
      $0.relativePath == relativePath
    }),
      let source = String(data: data, encoding: .utf8)
    else {
      return data
    }
    let projected = try ActorSourceProjector.project(
      source: source,
      input: input,
      profile: manifest.profile,
      targetEnvironment: targetEnvironment
    )
    return Data(projected.utf8)
  }

  static func generatedTargetModules(
    for profile: ActorGenerationProfile,
  ) -> Set<String> {
    var modules: Set<String> = [
      "ActorSystemCore",
      "Swift",
      "SwiftHTML",
      "SwiftWebActors",
      "SwiftWebStyle",
      "SwiftWebUI",
      "SwiftWebUIRuntime",
      "SwiftWebUITheme",
      "Synchronization",
    ]
    switch profile {
    case .nativeHost:
      modules = [
        "Swift", "Distributed", "Foundation", "FoundationEssentials",
        "Synchronization",
      ]
    case .standardClient:
      modules.formUnion([
        "ActorSystemDistributed", "Distributed", "Foundation",
        "FoundationEssentials", "JavaScriptKit",
      ])
    case .embeddedHost:
      modules.insert("ActorSystemEmbedded")
    case .embeddedClient:
      modules.formUnion(["ActorSystemEmbedded", "JavaScriptKit"])
    }
    return modules
  }

  static func generatedCustomConditions(
    profile: ActorGenerationProfile,
    role: GeneratedTargetRole
  ) -> Set<String> {
    switch (profile, role) {
    case (.standardClient, .rootApplication),
         (.standardClient, .actorDependency):
      ["SWIFTWEB_ACTORS"]
    default: []
    }
  }

  func installGeneratedSources(
    in destinationDirectory: URL
  ) throws {
    let destination = destinationDirectory.appendingPathComponent(
      "ActorSystemGenerated",
      isDirectory: true
    )
    let sources = try manifest.generatedFiles.compactMap { file -> GeneratedActorSource? in
      guard file.relativePath.hasSuffix(".swift") else {
        return nil
      }
      let source = generatedDirectory.appendingPathComponent(file.relativePath)
      return GeneratedActorSource(
        relativePath: file.relativePath,
        contents: try String(contentsOf: source, encoding: .utf8)
      )
    }
    _ = try ActorGeneratedSourceWriter.write(sources, to: destination)
  }

  static func clearGeneratedSources(
    in destinationDirectory: URL
  ) throws {
    let destination = destinationDirectory.appendingPathComponent(
      "ActorSystemGenerated",
      isDirectory: true
    )
    guard FileManager.default.fileExists(atPath: destination.path) else {
      return
    }
    _ = try ActorGeneratedSourceWriter.write([], to: destination)
  }
}

struct SwiftWebActorDependencyProjection: Sendable {
  let moduleName: String
  let dependencyModuleNames: [String]
  let clientImportedModuleNames: [String]
  let customConditions: Set<String>
  let upcomingFeatures: Set<String>
  let experimentalFeatures: Set<String>
  let sourceDirectory: URL
  let projection: SwiftWebActorProjection

  func installProjectedOriginalSources(
    in destinationDirectory: URL,
    fileWriter: GeneratedPackageFileWriter
  ) throws {
    let sourcePaths = Set(
      projection.manifest.inputSources.map(\.relativePath).filter {
        !GeneratedSourcePathPolicy.isServerOnlyActorDependency(relativePath: $0)
      }
    )
    let sourceDirectories = Set(sourcePaths.flatMap { relativePath -> [String] in
      let components = relativePath.split(separator: "/").map(String.init)
      guard components.count > 1 else {
        return []
      }
      return (1..<components.count).map { count in
        components.prefix(count).joined(separator: "/")
      }
    })
    try fileWriter.mirrorDirectoryContents(
      from: sourceDirectory,
      to: destinationDirectory,
      relativePath: "",
      shouldSkip: { relativePath in
        !sourcePaths.contains(relativePath)
          && !sourceDirectories.contains(relativePath)
      },
      shouldPreserve: { relativePath in
        relativePath == "ActorSystemGenerated"
          || relativePath.hasPrefix("ActorSystemGenerated/")
      },
      transform: { relativePath, data in
        try projection.project(relativePath: relativePath, data: data)
      }
    )
  }
}
