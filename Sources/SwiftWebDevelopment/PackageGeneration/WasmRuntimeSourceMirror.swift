import Foundation

struct WasmRuntimeSourceMirror: Sendable {
  let appPackageDirectory: URL
  let wasmPackageDirectory: URL
  let fileWriter: GeneratedPackageFileWriter

  func copyStandardSources(
    appProductName: String,
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL
  ) throws {
    try copyClientSources(appProductName: appProductName, to: wasmPackageDirectory)
    try copySwiftHTMLRuntimeSources(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try copyClientRuntimeSources(
      from: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try copyJavaScriptKitRuntimeSources(
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
  }

  func copyEmbeddedSources(
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL
  ) throws {
    try copySwiftHTMLClientRuntimeSources(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try copyJavaScriptKitRuntimeSources(
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
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

  private func copyClientSources(appProductName: String, to packageDirectory: URL) throws {
    let sourceDirectory =
      appPackageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(appProductName, isDirectory: true)
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

    try fileWriter.mirrorDirectoryContents(
      from: sourceDirectory,
      to: destinationDirectory,
      relativePath: "",
      shouldSkip: GeneratedSourcePathPolicy.isServerOnly(relativePath:),
      shouldPreserve: Self.shouldPreserveGeneratedAppSource(relativePath:),
      transform: expandClientSource(relativePath:data:)
    )
  }

  // Generated WASM packages compile without the SwiftWebMacros plugin, so the
  // @Actor accessor macro must be expanded while client sources are copied.
  private func expandClientSource(relativePath: String, data: Data) throws -> Data {
    guard relativePath.hasSuffix(".swift"),
      let source = String(data: data, encoding: .utf8)
    else {
      return data
    }
    let actorExpanded = try SwiftWebClientActorPropertyExpander.expandActorProperties(
      inSource: source,
      filePath: relativePath
    )
    // `#HTMLPreview` is a host-only Xcode preview; the vendored WASM copy of
    // SwiftHTML omits its macro declaration, so strip any usage here.
    let transformed = SwiftWebClientPreviewStripper.stripHTMLPreview(inSource: actorExpanded)
    guard transformed != source else {
      return data
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

  private func copySwiftHTMLClientRuntimeSources(
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL,
    to packageDirectory: URL
  ) throws {
    let sourceDirectory = try swiftHTMLClientRuntimeSourceDirectory(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    let destinationDirectory =
      packageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent("SwiftHTMLClientRuntime", isDirectory: true)
    try FileManager.default.createDirectory(
      at: destinationDirectory,
      withIntermediateDirectories: true
    )
    try fileWriter.mirrorDirectoryContents(
      from: sourceDirectory,
      to: destinationDirectory,
      relativePath: "",
      shouldSkip: { _ in false }
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

  private func swiftHTMLClientRuntimeSourceDirectory(
    swiftHTMLPackageDirectory: URL?,
    swiftWebPackageDirectory: URL
  ) throws -> URL {
    let candidates = Self.swiftHTMLClientRuntimeSourceDirectoryCandidates(
      swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
      appPackageDirectory: appPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    for candidate in candidates where Self.isSwiftHTMLClientRuntimeSourceDirectory(candidate) {
      return candidate
    }
    throw SwiftWebGeneratedPackageMaterializerError.swiftHTMLClientRuntimeSourcesNotFound(
      candidates
    )
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

  private static func swiftHTMLClientRuntimeSourceDirectoryCandidates(
    swiftHTMLPackageDirectory: URL?,
    appPackageDirectory: URL,
    swiftWebPackageDirectory: URL
  ) -> [URL] {
    let compiledPackageDirectory = PackageGenerationSourceLocator.packageDirectoryContainingThisFile()
    let explicitCandidates =
      swiftHTMLPackageDirectory.map {
        [$0.appendingPathComponent("Sources/SwiftHTMLClientRuntime", isDirectory: true)]
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
        parent.appendingPathComponent("swift-html/Sources/SwiftHTMLClientRuntime", isDirectory: true))
      candidates.append(
        parent.appendingPathComponent("SwiftHTML/Sources/SwiftHTMLClientRuntime", isDirectory: true))
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

  private static func isSwiftHTMLClientRuntimeSourceDirectory(_ sourceDirectory: URL) -> Bool {
    let documentSource = sourceDirectory.appendingPathComponent("ClientHTMLDocument.swift")
    let hostSource = sourceDirectory.appendingPathComponent("ClientDOMHost.swift")
    return FileManager.default.fileExists(atPath: documentSource.path)
      && FileManager.default.fileExists(atPath: hostSource.path)
  }

  private static func shouldSkipSwiftHTMLRuntimeSource(relativePath: String) -> Bool {
    let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
    return relativePath == "README.md" || firstComponent == "SwiftHTML.docc"
  }

  private static func shouldPreserveGeneratedAppSource(relativePath: String) -> Bool {
    relativePath == "SwiftWebGeneratedActorResolvers.swift"
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
        shouldSkip: { $0 == "README.md" }
      )
    }
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
