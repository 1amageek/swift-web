import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import Darwin
import Foundation

public struct SwiftWebGeneratedPackageMaterializer: Sendable {
  public var appPackageDirectory: URL
  public var generatedPackageDirectory: URL
  public var appProductName: String?
  public var serverProductName: String
  public var devProductName: String?
  public var wasmSplitBuildStrategy: SwiftWebWasmSplitBuildStrategy
  public var wasmRuntimeProfile: SwiftWebWasmRuntimeProfile

  public init(
    appPackageDirectory: URL,
    generatedPackageDirectory: URL? = nil,
    appProductName: String? = nil,
    serverProductName: String = "app-server",
    devProductName: String? = nil,
    wasmSplitBuildStrategy: SwiftWebWasmSplitBuildStrategy = .defaultValue(),
    wasmRuntimeProfile: SwiftWebWasmRuntimeProfile = .defaultValue()
  ) {
    let standardizedAppPackageDirectory = appPackageDirectory.standardizedFileURL
    self.appPackageDirectory = standardizedAppPackageDirectory
    self.generatedPackageDirectory =
      generatedPackageDirectory?.standardizedFileURL
      ?? standardizedAppPackageDirectory
      .appendingPathComponent(".swiftweb", isDirectory: true)
      .appendingPathComponent("generated", isDirectory: true)
      .standardizedFileURL
    self.appProductName = appProductName
    self.serverProductName = serverProductName
    self.devProductName = devProductName
    self.wasmSplitBuildStrategy = wasmSplitBuildStrategy
    self.wasmRuntimeProfile = wasmRuntimeProfile
  }

  private var layout: GeneratedPackageLayout {
    GeneratedPackageLayout(
      appPackageDirectory: appPackageDirectory,
      rootDirectory: generatedPackageDirectory
    )
  }

  private var serverPackageDirectory: URL {
    layout.serverPackageDirectory
  }

  private var devPackageDirectory: URL {
    layout.devPackageDirectory
  }

  private var wasmPackageDirectory: URL {
    layout.wasmPackageDirectory
  }

  private var developmentServerProductName: String {
    "\(serverProductName)-dev"
  }

  private static let wasmPackageResolvedIdentities: Set<String> = [
    "swift-actor-runtime"
  ]

  private var generatedFormats: [any GeneratedPackageFormat] {
    [
      ServerPackageFormat(),
      DevPackageFormat(),
      WasmPackageFormat(),
    ]
  }

  private var fileWriter: GeneratedPackageFileWriter {
    GeneratedPackageFileWriter()
  }

  private var packageResolvedSynchronizer: PackageResolvedSynchronizer {
    PackageResolvedSynchronizer(
      appPackageDirectory: appPackageDirectory,
      fileWriter: fileWriter
    )
  }

  private var wasmSourceMirror: WasmRuntimeSourceMirror {
    WasmRuntimeSourceMirror(
      appPackageDirectory: appPackageDirectory,
      wasmPackageDirectory: wasmPackageDirectory,
      fileWriter: fileWriter
    )
  }

  public func materialize() throws -> SwiftWebGeneratedPackage {
    let packageName = try SwiftWebPackageManifestInspector.packageName(in: appPackageDirectory)
    let appProductName = appProductName ?? packageName
    let devProductName = devProductName ?? "\(packageName)-dev"
    let swiftWebPackageDirectory = try resolveSwiftWebPackageDirectory()
    let swiftHTMLPackageDirectory = try resolveLocalSwiftHTMLPackageDirectory(
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    try FileManager.default.createDirectory(
      at: generatedPackageDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: serverPackageDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: devPackageDirectory,
      withIntermediateDirectories: true
    )
    try FileManager.default.createDirectory(
      at: wasmPackageDirectory,
      withIntermediateDirectories: true
    )
    return try withMaterializationLock {
      try materializeUnlocked(
        packageName: packageName,
        appProductName: appProductName,
        devProductName: devProductName,
        swiftWebPackageDirectory: swiftWebPackageDirectory,
        swiftHTMLPackageDirectory: swiftHTMLPackageDirectory
      )
    }
  }

  private func resolveLocalSwiftHTMLPackageDirectory(
    swiftWebPackageDirectory: URL
  ) throws -> URL? {
    if let appSwiftHTMLPackageDirectory =
      try SwiftWebPackageManifestInspector.optionalLocalDependencyRoot(
        named: "swift-html",
        in: appPackageDirectory
      )
    {
      return appSwiftHTMLPackageDirectory
    }

    return try SwiftWebPackageManifestInspector.optionalLocalDependencyRoot(
      named: "swift-html",
      in: swiftWebPackageDirectory
    )
  }

  private func resolveSwiftWebPackageDirectory() throws -> URL {
    if let root = try SwiftWebPackageManifestInspector.optionalPackageRoot(
      named: SwiftWebPackageReference.packageName,
      in: appPackageDirectory
    ) {
      return root
    }

    if let root = try Self.optionalConfiguredSwiftWebPackageDirectory() {
      return root
    }

    if let root = try Self.optionalCompiledSwiftWebPackageDirectory() {
      return root
    }

    if let root = try Self.optionalMintLocalSourceSwiftWebPackageDirectory() {
      return root
    }

    try resolveAppPackageDependencies()

    if let root = try SwiftWebPackageManifestInspector.optionalPackageRoot(
      named: SwiftWebPackageReference.packageName,
      in: appPackageDirectory
    ) {
      return root
    }

    throw SwiftWebGeneratedPackageMaterializerError.localDependencyNotFound(
      package: SwiftWebPackageReference.packageName,
      in: appPackageDirectory
    )
  }

  private static func optionalConfiguredSwiftWebPackageDirectory(
    environment: [String: String] = ProcessInfo.processInfo.environment
  ) throws -> URL? {
    guard let path = environment["SWIFT_WEB_PACKAGE_PATH"], !path.isEmpty else {
      return nil
    }

    return try optionalSwiftWebPackageDirectory(
      URL(fileURLWithPath: path, isDirectory: true).standardizedFileURL
    )
  }

  private static func optionalCompiledSwiftWebPackageDirectory() throws -> URL? {
    try optionalSwiftWebPackageDirectory(
      PackageGenerationSourceLocator.packageDirectoryContainingThisFile().standardizedFileURL
    )
  }

  private static func optionalMintLocalSourceSwiftWebPackageDirectory() throws -> URL? {
    guard let executableURL = currentExecutableURL() else {
      return nil
    }

    let components = executableURL.pathComponents
    guard
      let packagesIndex = components.lastIndex(of: "packages"),
      packagesIndex + 2 < components.count,
      components[packagesIndex + 2] == "build"
    else {
      return nil
    }

    let encodedPackageDirectory = components[packagesIndex + 1]
    guard encodedPackageDirectory.hasPrefix("_") else {
      return nil
    }

    let decodedPathComponents = encodedPackageDirectory
      .split(separator: "_")
      .map(String.init)
    guard !decodedPathComponents.isEmpty else {
      return nil
    }

    let packageDirectory = URL(
      fileURLWithPath: "/" + decodedPathComponents.joined(separator: "/"),
      isDirectory: true
    )
    .standardizedFileURL
    return try optionalSwiftWebPackageDirectory(packageDirectory)
  }

  private static func optionalSwiftWebPackageDirectory(_ packageDirectory: URL) throws -> URL? {
    let packageFile = packageDirectory.appendingPathComponent("Package.swift")
    guard FileManager.default.fileExists(atPath: packageFile.path) else {
      return nil
    }

    let packageName = try SwiftWebPackageManifestInspector.packageName(in: packageDirectory)
    guard packageName == SwiftWebPackageReference.packageName else {
      return nil
    }

    return packageDirectory
  }

  private static func currentExecutableURL() -> URL? {
    var size: UInt32 = 0
    _ = _NSGetExecutablePath(nil, &size)
    var buffer = [CChar](repeating: 0, count: Int(size))
    guard _NSGetExecutablePath(&buffer, &size) == 0 else {
      return nil
    }
    let pathBytes = buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }
    return URL(fileURLWithPath: String(decoding: pathBytes, as: UTF8.self))
      .resolvingSymlinksInPath()
      .standardizedFileURL
  }

  private func resolveAppPackageDependencies() throws {
    let configuration = SwiftWebDevRuntimeConfiguration(packageDirectory: appPackageDirectory)
    let toolchain = try SwiftWebHostSwiftToolchain.resolve(configuration: configuration)
    let process = Process()
    let output = Pipe()
    process.executableURL = toolchain.swiftExecutableURL
    process.arguments = ["package", "resolve"]
    process.currentDirectoryURL = appPackageDirectory
    process.environment = toolchain.applying(to: ProcessInfo.processInfo.environment)
    process.standardOutput = output
    process.standardError = output

    try process.run()
    let data = output.fileHandleForReading.readDataToEndOfFile()
    process.waitUntilExit()

    guard process.terminationStatus == 0 else {
      let message = String(data: data, encoding: .utf8) ?? ""
      throw SwiftWebGeneratedPackageMaterializerError.packageResolveFailed(
        package: appPackageDirectory,
        status: process.terminationStatus,
        output: message
      )
    }
  }

  private func materializeUnlocked(
    packageName: String,
    appProductName: String,
    devProductName: String,
    swiftWebPackageDirectory: URL,
    swiftHTMLPackageDirectory: URL?
  ) throws -> SwiftWebGeneratedPackage {
    let clientComponents = try discoverClientComponents(appProductName: appProductName)
    let wasmRuntimeTargets = WasmRuntimePlanner(
      appProductName: appProductName,
      splitBuildStrategy: wasmSplitBuildStrategy
    )
    .runtimeTargets(for: clientComponents)
    let wasmRuntimeTargetNames = wasmRuntimeTargets.map(\.targetName)
    let wasmProductNames = wasmRuntimeTargetNames.map(
      GeneratedPackageNameFormatter.productName(forWasmRuntimeTarget:)
    )
    let wasmRuntimes = wasmRuntimeTargets.map { target in
      SwiftWebGeneratedWasmRuntime(
        packageDirectory: wasmPackageDirectory,
        targetName: target.targetName,
        productName: GeneratedPackageNameFormatter.productName(
          forWasmRuntimeTarget: target.targetName
        ),
        componentTypeNames: target.componentTypeNames,
        bundleID: target.bundleID,
        assetPath: GeneratedPackageNameFormatter.assetPath(
          forWasmRuntimeTarget: target.targetName
        ),
        linkMode: target.linkMode
      )
    }

    try removeLegacyMaterializationLockFile()
    try removeLegacySinglePackageLayout()
    switch wasmRuntimeProfile {
    case .standard:
      try wasmSourceMirror.copyStandardSources(
        appProductName: appProductName,
        swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
        swiftWebPackageDirectory: swiftWebPackageDirectory
      )
    case .embedded:
      try wasmSourceMirror.copyEmbeddedSources(
        swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
        swiftWebPackageDirectory: swiftWebPackageDirectory
      )
    }
    try wasmSourceMirror.removeStaleWasmSourceTargets(
      keeping: Set(
        wasmRuntimeProfile.wasmSourceTargets(appProductName: appProductName)
          + wasmRuntimeTargetNames
      )
    )
    let renderContext = GeneratedPackageRenderContext(
      layout: layout,
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      appPackageName: packageName,
      appPackageDependencyName: GeneratedPackageNameFormatter.localPackageIdentity(
        for: appPackageDirectory
      ),
      appProductName: appProductName,
      serverProductName: serverProductName,
      developmentServerProductName: developmentServerProductName,
      devProductName: devProductName,
      wasmRuntimeTargets: wasmRuntimeTargets,
      actorRuntimeDependencyDeclaration: try packageResolvedSynchronizer.actorRuntimeDependencyDeclaration(
        fallbackPackageDirectory: swiftWebPackageDirectory
      ),
      wasmRuntimeProfile: wasmRuntimeProfile
    )
    let generatedFiles = try generatedFormats.flatMap { format in
      try format.files(context: renderContext)
    }
    for file in generatedFiles where file.relativePath == "Package.swift" {
      try fileWriter.removeGeneratedBuildDirectoryIfPackageChanged(
        in: layout.packageDirectory(for: file.packageKind),
        nextPackageSwift: file.contents
      )
    }
    for file in generatedFiles {
      try fileWriter.write(
        file.contents,
        to: file.relativePath,
        in: layout.packageDirectory(for: file.packageKind)
      )
    }
    try packageResolvedSynchronizer.sync(
      to: serverPackageDirectory,
      fallbackPackageDirectory: swiftWebPackageDirectory
    )
    try packageResolvedSynchronizer.sync(
      to: devPackageDirectory,
      fallbackPackageDirectory: swiftWebPackageDirectory
    )
    try packageResolvedSynchronizer.sync(
      to: wasmPackageDirectory,
      fallbackPackageDirectory: swiftWebPackageDirectory,
      keepingIdentities: Self.wasmPackageResolvedIdentities
    )

    return SwiftWebGeneratedPackage(
      appPackageDirectory: appPackageDirectory,
      rootDirectory: generatedPackageDirectory,
      packageDirectory: serverPackageDirectory,
      devPackageDirectory: devPackageDirectory,
      wasmPackageDirectory: wasmPackageDirectory,
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      appProductName: appProductName,
      serverProductName: serverProductName,
      developmentServerProductName: developmentServerProductName,
      devProductName: devProductName,
      wasmProductNames: wasmProductNames,
      wasmRuntimes: wasmRuntimes
    )
  }

  private func withMaterializationLock<T>(_ body: () throws -> T) throws -> T {
    let descriptor = open(
      generatedPackageDirectory.path,
      O_RDONLY
    )
    guard descriptor >= 0 else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationLockOpenFailed(
        generatedPackageDirectory,
        errno
      )
    }
    defer {
      _ = close(descriptor)
    }

    guard flock(descriptor, LOCK_EX) == 0 else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationLockFailed(
        generatedPackageDirectory,
        errno
      )
    }
    defer {
      _ = flock(descriptor, LOCK_UN)
    }

    return try body()
  }

  private func removeLegacyMaterializationLockFile() throws {
    let lockFile = generatedPackageDirectory.appendingPathComponent(".materialize.lock")
    if FileManager.default.fileExists(atPath: lockFile.path) {
      try fileWriter.removeGeneratedItem(at: lockFile)
    }
  }

  private func removeLegacySinglePackageLayout() throws {
    for name in ["Package.swift", "Package.resolved"] {
      let url = generatedPackageDirectory.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: url.path) {
        try fileWriter.removeGeneratedItem(at: url)
      }
    }

    for name in ["Sources", ".build"] {
      let url = generatedPackageDirectory.appendingPathComponent(name, isDirectory: true)
      if FileManager.default.fileExists(atPath: url.path) {
        try fileWriter.removeGeneratedItem(at: url)
      }
    }
  }

  private func discoverClientComponents(appProductName: String) throws
    -> [ClientComponentDeclaration]
  {
    let sourceDirectory =
      appPackageDirectory
      .appendingPathComponent("Sources", isDirectory: true)
      .appendingPathComponent(appProductName, isDirectory: true)
    guard FileManager.default.fileExists(atPath: sourceDirectory.path) else {
      throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(sourceDirectory)
    }

    let swiftFiles = try collectSwiftFiles(
      in: sourceDirectory,
      relativePath: ""
    )

    return try SwiftWebClientComponentDiscovery.discover(in: swiftFiles)
  }

  private func collectSwiftFiles(
    in directory: URL,
    relativePath: String
  ) throws -> [(url: URL, relativePath: String)] {
    let children = try FileManager.default.contentsOfDirectory(
      at: directory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var files: [(url: URL, relativePath: String)] = []
    for child in children {
      let relativeChildPath =
        relativePath.isEmpty
        ? child.lastPathComponent
        : "\(relativePath)/\(child.lastPathComponent)"
      guard !GeneratedSourcePathPolicy.isServerOnly(relativePath: relativeChildPath) else {
        continue
      }

      let values = try child.resourceValues(forKeys: [.isDirectoryKey])
      if values.isDirectory == true {
        files.append(contentsOf: try collectSwiftFiles(in: child, relativePath: relativeChildPath))
      } else if child.pathExtension == "swift" {
        files.append((child, relativeChildPath))
      }
    }
    return files
  }

}
