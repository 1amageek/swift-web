import ActorSystemGeneration
import Foundation
import SwiftWebWasmBuild

struct WasmRuntimeSourceMirror: Sendable {
  let appPackageDirectory: URL
  let wasmPackageDirectory: URL
  let wasmRuntimeProfile: SwiftWebWasmRuntimeProfile
  let fileWriter: GeneratedPackageFileWriter

  func copyStandardSources(
    appProductName: String,
    appSourceDirectory: URL,
    appSourceFiles: [URL],
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL,
    actorProjection: SwiftWebActorProjection?,
    actorDependencyProjections: [SwiftWebActorDependencyProjection]
  ) throws {
    try copyClientSources(
      appProductName: appProductName,
      sourceDirectory: appSourceDirectory,
      sourceFiles: appSourceFiles,
      to: wasmPackageDirectory,
      actorProjection: actorProjection
    )
    try copySwiftHTMLRuntimeSources(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try copyClientRuntimeSources(
      from: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try copyActorSystemRuntimeSources(
      from: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try installActorDependencyProjections(actorDependencyProjections)
    try copyJavaScriptKitRuntimeSources(
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
  }

  private func installActorDependencyProjections(
    _ dependencies: [SwiftWebActorDependencyProjection]
  ) throws {
    let sourcesDirectory = wasmPackageDirectory.appendingPathComponent(
      "Sources",
      isDirectory: true
    )
    for dependency in dependencies {
      let destination = sourcesDirectory.appendingPathComponent(
        dependency.moduleName,
        isDirectory: true
      )
      try FileManager.default.createDirectory(
        at: destination,
        withIntermediateDirectories: true
      )
      try dependency.installProjectedOriginalSources(
        in: destination,
        fileWriter: fileWriter
      )
      try dependency.projection.installGeneratedSources(in: destination)
    }
  }

  func removeStaleWasmSourceTargets(keeping names: Set<String>) throws {
    let sourcesDirectory = wasmPackageDirectory.appendingPathComponent("Sources", isDirectory: true)
    guard FileManager.default.fileExists(atPath: sourcesDirectory.path) else {
      return
    }
    let children = try FileManager.default.contentsOfDirectory(
      at: sourcesDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    for child in children where !names.contains(child.lastPathComponent) {
      try fileWriter.removeGeneratedItem(at: child)
    }
  }

  private func copyClientSources(
    appProductName: String,
    sourceDirectory: URL,
    sourceFiles: [URL],
    to packageDirectory: URL,
    actorProjection: SwiftWebActorProjection?
  ) throws {
    guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
      throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(sourceDirectory)
    }

    let destinationDirectory =
      packageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(appProductName, isDirectory: true)
    try FileManager.default.createDirectory(
      at: destinationDirectory,
      withIntermediateDirectories: true
    )

    let sourceRootPath = sourceDirectory.standardizedFileURL.path
    let sourcePrefix = sourceRootPath.hasSuffix("/") ? sourceRootPath : sourceRootPath + "/"
    var includedSourcePaths = Set<String>()
    for sourceFile in sourceFiles {
      let path = sourceFile.standardizedFileURL.path
      guard path.hasPrefix(sourcePrefix) else {
        throw ActorGenerationError.schemaConflict(
          reason: "SwiftPM target source \(path) is outside declared target directory \(sourceRootPath)"
        )
      }
      let relativePath = String(path.dropFirst(sourcePrefix.count))
      guard !GeneratedSourcePathPolicy.isServerOnly(relativePath: relativePath),
            !relativePath.hasPrefix("ActorSystemGenerated/") else {
        continue
      }
      includedSourcePaths.insert(relativePath)
    }
    let includedDirectories = Set(includedSourcePaths.flatMap { relativePath -> [String] in
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
        !includedSourcePaths.contains(relativePath)
          && !includedDirectories.contains(relativePath)
      },
      shouldPreserve: { relativePath in
        Self.shouldPreserveGeneratedAppSource(
          relativePath: relativePath,
          hasActorProjection: actorProjection != nil
        )
      },
      transform: { relativePath, data in
        try expandClientSource(
          relativePath: relativePath,
          data: data,
          actorProjection: actorProjection
        )
      }
    )
    try actorProjection?.installGeneratedSources(
      in: destinationDirectory
    )
  }

  // Generated WASM packages compile without the SwiftWebMacros plugin, so the
  // @RemoteActor accessor macro must be expanded while client sources are copied.
  private func expandClientSource(
    relativePath: String,
    data: Data,
    actorProjection: SwiftWebActorProjection?
  ) throws -> Data {
    guard relativePath.hasSuffix(".swift") else {
      return data
    }
    let projectedData = try actorProjection?.project(
      relativePath: relativePath,
      data: data
    ) ?? data
    guard let source = String(data: projectedData, encoding: .utf8) else {
      return projectedData
    }
    let actorExpanded = try SwiftWebClientActorPropertyExpander.expandActorProperties(
      inSource: source,
      filePath: relativePath
    )
    // SwiftHTML's `#Preview` is a host-only Xcode preview; the vendored WASM copy
    // of SwiftHTML omits its macro declaration, so strip any usage here.
    let transformed = SwiftWebClientPreviewStripper.stripHTMLPreview(inSource: actorExpanded)
    guard transformed != source else {
      return projectedData
    }
    return Data(transformed.utf8)
  }

  private func copySwiftHTMLRuntimeSources(
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL,
    to packageDirectory: URL
  ) throws {
    let sourceDirectory = try swiftHTMLSourceDirectory(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    let destinationDirectory =
      packageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("SwiftHTML", isDirectory: true)
    try FileManager.default.createDirectory(
      at: destinationDirectory,
      withIntermediateDirectories: true
    )
    try fileWriter.mirrorDirectoryContents(
      from: sourceDirectory,
      to: destinationDirectory,
      relativePath: "",
      shouldSkip: Self.shouldSkipSwiftHTMLRuntimeSource(relativePath:)
    )
  }

  private func swiftHTMLSourceDirectory(
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL
  ) throws -> URL {
    let candidates = Self.swiftHTMLSourceDirectoryCandidates(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      appPackageDirectory: appPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    for candidate in candidates where Self.isSwiftHTMLSourceDirectory(candidate) {
      return candidate
    }
    throw SwiftWebGeneratedPackageMaterializerError.swiftHTMLRuntimeSourcesNotFound(candidates)
  }

  private static func swiftHTMLSourceDirectoryCandidates(
    swiftHTMLPackageDirectory: URL?,
    appPackageDirectory: URL,
    swiftWebPackageDirectory: URL
  ) -> [URL] {
    let compiledPackageDirectory = PackageGenerationSourceLocator.packageDirectoryContainingThisFile()
    let explicitCandidates =
      swiftHTMLPackageDirectory.map {
        [$0.appendingPathComponent("Sources/SwiftHTML", isDirectory: true)]
      } ?? []
    let checkoutParents = [
      appPackageDirectory.appendingPathComponent(".build/checkouts", isDirectory: true),
      swiftWebPackageDirectory.appendingPathComponent(".build/checkouts", isDirectory: true),
      swiftWebPackageDirectory.deletingLastPathComponent(),
      compiledPackageDirectory.appendingPathComponent(".build/checkouts", isDirectory: true),
      compiledPackageDirectory.deletingLastPathComponent(),
    ]

    var candidates = explicitCandidates
    for parent in checkoutParents {
      candidates.append(
        parent.appendingPathComponent("swift-html/Sources/SwiftHTML", isDirectory: true))
      candidates.append(
        parent.appendingPathComponent("SwiftHTML/Sources/SwiftHTML", isDirectory: true))
    }

    var seen = Set<String>()
    return candidates.filter { candidate in
      let path = candidate.standardizedFileURL.path
      guard !seen.contains(path) else {
        return false
      }
      seen.insert(path)
      return true
    }
  }

  private static func isSwiftHTMLSourceDirectory(_ sourceDirectory: URL) -> Bool {
    let htmlSource = sourceDirectory.appendingPathComponent("Core/HTML.swift")
    let rendererSource = sourceDirectory.appendingPathComponent("Rendering/HTMLRenderer.swift")
    return FileManager.default.fileExists(atPath: htmlSource.path)
      && FileManager.default.fileExists(atPath: rendererSource.path)
  }

  private static func shouldSkipSwiftHTMLRuntimeSource(relativePath: String) -> Bool {
    let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
    return relativePath == "README.md"
      || firstComponent == "Preview"
      || firstComponent == "SwiftHTML.docc"
  }

  private static func shouldPreserveGeneratedAppSource(
    relativePath: String,
    hasActorProjection: Bool
  ) -> Bool {
    relativePath == "SwiftWebGeneratedActorResolvers.swift"
      || (hasActorProjection && (
        relativePath == "ActorSystemGenerated"
          || relativePath.hasPrefix("ActorSystemGenerated/")
      ))
  }

  private func copyClientRuntimeSources(
    from swiftWebPackageDirectory: URL, to packageDirectory: URL
  ) throws {
    let runtimeSources: [(sourcePath: String, targetName: String)] = [
      ("SwiftWebUI/Style", "SwiftWebStyle"),
      ("SwiftWebRuntime/Actors", "SwiftWebActors"),
      ("SwiftWebUI/Theme", "SwiftWebUITheme"),
      ("SwiftWebUI/Components", "SwiftWebUI"),
      ("SwiftWebBrowser/ClientRuntime", "SwiftWebUIRuntime"),
    ]
    for runtimeSource in runtimeSources {
      let sourceDirectory =
        swiftWebPackageDirectory
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(runtimeSource.sourcePath, isDirectory: true)
      let destinationDirectory =
        packageDirectory
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(runtimeSource.targetName, isDirectory: true)
      try FileManager.default.createDirectory(
        at: destinationDirectory,
        withIntermediateDirectories: true
      )
      try fileWriter.mirrorDirectoryContents(
        from: sourceDirectory,
        to: destinationDirectory,
        relativePath: "",
        shouldSkip: { relativePath in
          relativePath == "README.md"
        }
      )
    }
  }

  private func copyActorSystemRuntimeSources(
    from swiftWebPackageDirectory: URL,
    to packageDirectory: URL
  ) throws {
    let profileTarget = switch wasmRuntimeProfile {
    case .standard:
      "ActorSystemDistributed"
    case .embedded:
      "ActorSystemEmbedded"
    }
    let targetNames = ["ActorSystemCore", profileTarget]
    let actorSystemSources = try actorSystemSourceRoot(
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      targetNames: targetNames
    )
    for targetName in targetNames {
      let sourceDirectory = actorSystemSources.appendingPathComponent(
        targetName,
        isDirectory: true
      )
      let destinationDirectory = packageDirectory
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(targetName, isDirectory: true)
      try FileManager.default.createDirectory(
        at: destinationDirectory,
        withIntermediateDirectories: true
      )
      try fileWriter.mirrorDirectoryContents(
        from: sourceDirectory,
        to: destinationDirectory,
        relativePath: "",
        shouldSkip: { $0 == "README.md" }
      )
    }
  }

  private func actorSystemSourceRoot(
    swiftWebPackageDirectory: URL,
    targetNames: [String]
  ) throws -> URL {
    let compiledPackageDirectory = PackageGenerationSourceLocator
      .packageDirectoryContainingThisFile()
    let candidates = [
      swiftWebPackageDirectory
        .appendingPathComponent("Packages/swift-actor-system/Sources", isDirectory: true),
      compiledPackageDirectory
        .appendingPathComponent("Packages/swift-actor-system/Sources", isDirectory: true),
    ]
    for candidate in candidates where targetNames.allSatisfy({ targetName in
      FileManager.default.fileExists(
        atPath: candidate.appendingPathComponent(targetName, isDirectory: true).path
      )
    }) {
      return candidate
    }
    throw SwiftWebGeneratedPackageMaterializerError.actorSystemRuntimeSourcesNotFound(
      candidates
    )
  }

  private func copyJavaScriptKitRuntimeSources(
    swiftWebPackageDirectory: URL,
    to packageDirectory: URL
  ) throws {
    let sourceRoot = try javaScriptKitSourceRoot(swiftWebPackageDirectory: swiftWebPackageDirectory)
    let sourcesDirectory = packageDirectory.appendingPathComponent("Sources", isDirectory: true)

    let javaScriptKitSourceDirectory = sourceRoot.appendingPathComponent(
      "JavaScriptKit", isDirectory: true)
    let javaScriptKitDestinationDirectory = sourcesDirectory.appendingPathComponent(
      "JavaScriptKit",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: javaScriptKitDestinationDirectory,
      withIntermediateDirectories: true
    )
    try fileWriter.mirrorDirectoryContents(
      from: javaScriptKitSourceDirectory,
      to: javaScriptKitDestinationDirectory,
      relativePath: "",
      shouldSkip: Self.shouldSkipJavaScriptKitRuntimeSource(relativePath:)
    )

    let cJavaScriptKitSourceDirectory = sourceRoot.appendingPathComponent(
      "_CJavaScriptKit", isDirectory: true)
    let cJavaScriptKitDestinationDirectory = sourcesDirectory.appendingPathComponent(
      "_CJavaScriptKit",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: cJavaScriptKitDestinationDirectory,
      withIntermediateDirectories: true
    )
    try fileWriter.mirrorDirectoryContents(
      from: cJavaScriptKitSourceDirectory,
      to: cJavaScriptKitDestinationDirectory,
      relativePath: "",
      shouldSkip: { _ in false }
    )
  }

  private func javaScriptKitSourceRoot(swiftWebPackageDirectory: URL) throws -> URL {
    let candidates = Self.javaScriptKitSourceRootCandidates(
      appPackageDirectory: appPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    for candidate in candidates where Self.isJavaScriptKitSourceRoot(candidate) {
      return candidate
    }
    throw SwiftWebGeneratedPackageMaterializerError.javaScriptKitRuntimeSourcesNotFound(candidates)
  }

  private static func javaScriptKitSourceRootCandidates(
    appPackageDirectory: URL,
    swiftWebPackageDirectory: URL
  ) -> [URL] {
    let compiledPackageDirectory = PackageGenerationSourceLocator.packageDirectoryContainingThisFile()
    let checkoutParents = [
      appPackageDirectory.appendingPathComponent(".build/checkouts", isDirectory: true),
      swiftWebPackageDirectory.appendingPathComponent(".build/checkouts", isDirectory: true),
      swiftWebPackageDirectory.deletingLastPathComponent(),
      compiledPackageDirectory.appendingPathComponent(".build/checkouts", isDirectory: true),
      compiledPackageDirectory.deletingLastPathComponent(),
    ]

    var candidates: [URL] = []
    for parent in checkoutParents {
      candidates.append(parent.appendingPathComponent("JavaScriptKit/Sources", isDirectory: true))
      candidates.append(parent.appendingPathComponent("javascriptkit/Sources", isDirectory: true))
    }

    var seen = Set<String>()
    return candidates.filter { candidate in
      let path = candidate.standardizedFileURL.path
      guard !seen.contains(path) else {
        return false
      }
      seen.insert(path)
      return true
    }
  }

  private static func isJavaScriptKitSourceRoot(_ sourceRoot: URL) -> Bool {
    let javaScriptKitDirectory = sourceRoot.appendingPathComponent(
      "JavaScriptKit", isDirectory: true)
    let cJavaScriptKitDirectory = sourceRoot.appendingPathComponent(
      "_CJavaScriptKit", isDirectory: true)
    let jsObjectSource =
      javaScriptKitDirectory
      .appendingPathComponent("FundamentalObjects/JSObject.swift")
    let cHeader =
      cJavaScriptKitDirectory
      .appendingPathComponent("include/_CJavaScriptKit.h")
    return FileManager.default.fileExists(atPath: jsObjectSource.path)
      && FileManager.default.fileExists(atPath: cHeader.path)
  }

  private static func shouldSkipJavaScriptKitRuntimeSource(relativePath: String) -> Bool {
    let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
    return relativePath == "Macros.swift"
      || firstComponent == "Runtime"
      || firstComponent == "Documentation.docc"
  }
}
