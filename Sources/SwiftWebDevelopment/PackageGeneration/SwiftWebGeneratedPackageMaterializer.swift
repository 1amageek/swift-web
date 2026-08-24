import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import ActorSystemBuildSupport
import ActorSystemGeneration
import Foundation
import SwiftParser
import SwiftSyntax

#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

private struct SwiftWebActorProjectionSet: Sendable {
  let root: SwiftWebActorProjection?
  let dependencies: [SwiftWebActorDependencyProjection]

  static let empty = SwiftWebActorProjectionSet(root: nil, dependencies: [])
}

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

  private var wasmPackageResolvedIdentities: Set<String> {
    []
  }

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
      wasmRuntimeProfile: wasmRuntimeProfile,
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
    return try withMaterializationLock {
      let packageResolvedSnapshot = try packageResolvedSynchronizer.snapshot(
        fallbackPackageDirectory: swiftWebPackageDirectory
      )
      let configuration = SwiftWebDevRuntimeConfiguration(
        packageDirectory: appPackageDirectory
      )
      let toolchain = try SwiftWebHostSwiftToolchain.resolve(
        configuration: configuration
      )
      let nativeTargetEnvironment = try ActorCompilerTargetEnvironmentResolver.resolve(
        swiftCompiler: toolchain.swiftCompilerURL,
        availableModules: SwiftWebActorProjection.generatedTargetModules(for: .nativeHost)
      )
      let nativeTargetGraph = try SwiftWebEvaluatedPackageTargetGraphLoader.load(
        packageDirectory: appPackageDirectory,
        swiftExecutable: toolchain.swiftExecutableURL,
        environment: toolchain.applying(to: ProcessInfo.processInfo.environment),
        targetEnvironment: nativeTargetEnvironment
      )
      guard let nativeAppTarget = nativeTargetGraph.target(named: appProductName) else {
        throw ActorGenerationError.schemaConflict(
          reason: "SwiftPM target graph has no application target named \(appProductName)"
        )
      }
      let transaction = GeneratedPackageMaterializationTransaction(
        generatedPackageDirectory: generatedPackageDirectory,
        nativeSourceDirectory: nativeAppTarget.sourceDirectory
      )
      do {
        try transaction.prepare()
        var stagedMaterializer = self
        stagedMaterializer.generatedPackageDirectory =
          transaction.stagingGeneratedPackageDirectory
        try stagedMaterializer.createGeneratedPackageDirectories()
        let stagedPackage = try stagedMaterializer.materializeUnlocked(
          packageName: packageName,
          appProductName: appProductName,
          devProductName: devProductName,
          swiftWebPackageDirectory: swiftWebPackageDirectory,
          swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
          nativeActorSourceDirectory: transaction.stagingNativeSourceDirectory,
          appSourceDirectory: nativeAppTarget.sourceDirectory,
          appSourceFiles: nativeAppTarget.sourceFiles,
          toolchain: toolchain,
          nativeTargetEnvironment: nativeTargetEnvironment,
          nativeTargetGraph: nativeTargetGraph,
          packageResolvedSnapshot: packageResolvedSnapshot
        )
        try transaction.commit()
        return relocate(stagedPackage)
      } catch {
        let materializationError = error
        do {
          try transaction.discardPreparedArtifacts()
        } catch {
          throw SwiftWebGeneratedPackageMaterializerError.materializationCleanupFailed(
            transaction.stagingGeneratedPackageDirectory,
            "\(materializationError); cleanup: \(error)"
          )
        }
        throw materializationError
      }
    }
  }

  private func createGeneratedPackageDirectories() throws {
    for directory in [
      generatedPackageDirectory,
      serverPackageDirectory,
      devPackageDirectory,
      wasmPackageDirectory,
    ] {
      try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
      )
    }
  }

  private func relocate(
    _ stagedPackage: SwiftWebGeneratedPackage
  ) -> SwiftWebGeneratedPackage {
    SwiftWebGeneratedPackage(
      appPackageDirectory: appPackageDirectory,
      rootDirectory: generatedPackageDirectory,
      packageDirectory: serverPackageDirectory,
      devPackageDirectory: devPackageDirectory,
      wasmPackageDirectory: wasmPackageDirectory,
      swiftWebPackageDirectory: stagedPackage.swiftWebPackageDirectory,
      appProductName: stagedPackage.appProductName,
      serverProductName: stagedPackage.serverProductName,
      developmentServerProductName: stagedPackage.developmentServerProductName,
      devProductName: stagedPackage.devProductName,
      wasmProductNames: stagedPackage.wasmProductNames,
      wasmRuntimes: stagedPackage.wasmRuntimes.map { runtime in
        SwiftWebGeneratedWasmRuntime(
          packageDirectory: wasmPackageDirectory,
          targetName: runtime.targetName,
          productName: runtime.productName,
          componentTypeNames: runtime.componentTypeNames,
          bundleID: runtime.bundleID,
          assetPath: runtime.assetPath,
          linkMode: runtime.linkMode
        )
      }
    )
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
    // An explicit source override must win over an app's resolved checkout.
    // Local CLI development otherwise combines the current generator with an
    // older mirrored runtime from the app's remote dependency checkout.
    if let root = try Self.optionalConfiguredSwiftWebPackageDirectory() {
      return root
    }

    if let root = try SwiftWebPackageManifestInspector.optionalPackageRoot(
      named: SwiftWebPackageReference.packageName,
      in: appPackageDirectory
    ) {
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
    #if canImport(Darwin)
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
    #elseif canImport(Glibc)
    var buffer = [CChar](repeating: 0, count: 4_096)
    let byteCount = buffer.withUnsafeMutableBufferPointer { pointer in
      guard let baseAddress = pointer.baseAddress else {
        return -1
      }
      return Glibc.readlink("/proc/self/exe", baseAddress, pointer.count - 1)
    }
    guard byteCount > 0 else {
      return nil
    }
    let pathBytes = buffer.prefix(Int(byteCount)).map { UInt8(bitPattern: $0) }
    return URL(fileURLWithPath: String(decoding: pathBytes, as: UTF8.self))
      .resolvingSymlinksInPath()
      .standardizedFileURL
    #else
    return nil
    #endif
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
    swiftHTMLPackageDirectory: URL?,
    nativeActorSourceDirectory: URL,
    appSourceDirectory: URL,
    appSourceFiles: [URL],
    toolchain: SwiftWebHostSwiftToolchain,
    nativeTargetEnvironment: ActorGenerationTargetEnvironment,
    nativeTargetGraph: SwiftWebEvaluatedPackageTargetGraph,
    packageResolvedSnapshot: PackageResolvedSynchronizer.Snapshot?
  ) throws -> SwiftWebGeneratedPackage {
    guard FileManager.default.fileExists(atPath: appSourceDirectory.path) else {
      throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(
        appSourceDirectory
      )
    }
    let clientSourceFiles = try sourceFiles(
      appSourceFiles,
      relativeTo: appSourceDirectory,
      includingServerOnly: false
    )
    let clientComponents = try SwiftWebClientComponentDiscovery.discover(
      in: clientSourceFiles
    )
    let clientEnvironmentKeyTypeNames = try SwiftWebClientEnvironmentKeyDiscovery.discover(
      in: clientSourceFiles
    )
    let wasmRuntimeTargets = WasmRuntimePlanner(
      appProductName: appProductName,
      splitBuildStrategy: wasmSplitBuildStrategy
    )
    .runtimeTargets(for: clientComponents)
    let legacyContracts = wasmRuntimeTargets
      .flatMap(\.actorContracts)
      .filter(\.isLegacyExistential)
      .map(\.serviceTypeName)
    if !legacyContracts.isEmpty {
      throw SwiftWebGeneratedPackageMaterializerError.legacyActorContractsUnsupported(
        profile: wasmRuntimeProfile,
        contracts: Array(Set(legacyContracts)).sorted()
      )
    }
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
    let nativeActorProjectionSet = try makeActorProjection(
      appProductName: appProductName,
      profile: .nativeHost,
      toolchain: toolchain,
      compilerTargetEnvironment: nativeTargetEnvironment,
      targetGraph: nativeTargetGraph
    )
    guard let nativeAppTarget = nativeTargetGraph.target(named: appProductName) else {
      throw ActorGenerationError.schemaConflict(
        reason: "SwiftPM target graph has no application target named \(appProductName)"
      )
    }
    let clientAppTarget: SwiftWebEvaluatedPackageTargetGraph.Target?
    let clientActorProjectionSet: SwiftWebActorProjectionSet
    let embeddedUnicodeDataTablesLibraryPath: String?
    if wasmRuntimeTargets.isEmpty {
      clientAppTarget = nil
      clientActorProjectionSet = .empty
      embeddedUnicodeDataTablesLibraryPath = nil
    } else {
      let clientActorProfile: ActorGenerationProfile
      switch wasmRuntimeProfile {
      case .standard:
        clientActorProfile = .standardClient
      case .embedded:
        clientActorProfile = .embeddedClient
      }
      let wasmToolchain = try SwiftWebWasmToolchain.resolve(
        sdkName: wasmRuntimeProfile.defaultSwiftSDKName
      )
      let wasmSDKCompilerConfiguration =
        try SwiftWebWasmSDKCompilerConfiguration.resolve(
          sdkName: wasmToolchain.sdkName
        )
      switch wasmRuntimeProfile {
      case .standard:
        embeddedUnicodeDataTablesLibraryPath = nil
      case .embedded:
        embeddedUnicodeDataTablesLibraryPath = try wasmToolchain
          .embeddedUnicodeDataTablesLibraryURL()
          .path
      }
      let clientTargetEnvironment = try ActorCompilerTargetEnvironmentResolver.resolve(
        swiftCompiler: wasmToolchain.swiftCompilerURL,
        compilerArguments: wasmSDKCompilerConfiguration.compilerArguments + [
          "-enable-upcoming-feature", "ApproachableConcurrency",
        ],
        availableModules: SwiftWebActorProjection.generatedTargetModules(
          for: clientActorProfile
        ),
        featureProbeCandidates: ["Embedded"]
      )
      let clientTargetGraph = try SwiftWebEvaluatedPackageTargetGraphLoader.load(
        packageDirectory: appPackageDirectory,
        swiftExecutable: toolchain.swiftExecutableURL,
        environment: toolchain.applying(to: ProcessInfo.processInfo.environment),
        targetEnvironment: clientTargetEnvironment
      )
      guard let resolvedClientAppTarget = clientTargetGraph.target(named: appProductName) else {
        throw ActorGenerationError.schemaConflict(
          reason: "SwiftPM target graph has no application target named \(appProductName)"
        )
      }
      clientAppTarget = resolvedClientAppTarget
      clientActorProjectionSet = try makeActorProjection(
        appProductName: appProductName,
        profile: clientActorProfile,
        toolchain: toolchain,
        compilerTargetEnvironment: clientTargetEnvironment,
        targetGraph: clientTargetGraph
      )
    }
    try validateGeneratedWasmTargetNames(
      appProductName: appProductName,
      wasmRuntimeTargetNames: wasmRuntimeTargetNames,
      actorDependencyModuleNames: clientActorProjectionSet.dependencies.map(\.moduleName)
    )

    try installNativeActorProjection(
      nativeActorProjectionSet.root,
      destinationSourceDirectory: nativeActorSourceDirectory
    )

    try removeLegacyMaterializationLockFile()
    try removeLegacySinglePackageLayout()
    if let clientAppTarget {
      try wasmSourceMirror.copyStandardSources(
        appProductName: appProductName,
        appSourceDirectory: clientAppTarget.sourceDirectory,
        appSourceFiles: clientAppTarget.sourceFiles,
        swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
        swiftWebPackageDirectory: swiftWebPackageDirectory,
        actorProjection: clientActorProjectionSet.root,
        actorDependencyProjections: clientActorProjectionSet.dependencies
      )
    }
    try wasmSourceMirror.removeStaleWasmSourceTargets(
      keeping: clientAppTarget == nil
        ? []
        : Set(
          wasmRuntimeProfile.wasmSourceTargets(appProductName: appProductName)
            + wasmRuntimeTargetNames
            + clientActorProjectionSet.dependencies.map(\.moduleName)
        )
    )
    let appTarget = clientAppTarget ?? nativeAppTarget
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
      clientEnvironmentKeyTypeNames: clientEnvironmentKeyTypeNames,
      wasmRuntimeProfile: wasmRuntimeProfile,
      embeddedUnicodeDataTablesLibraryPath: embeddedUnicodeDataTablesLibraryPath,
      nativeActorBootstrapTypeName: nativeActorProjectionSet.root?.manifest.bootstrapTypeName,
      clientActorBootstrapTypeName: clientActorProjectionSet.root?.manifest.bootstrapTypeName,
      appActorCustomConditions: appTarget.customConditions,
      appActorUpcomingFeatures: appTarget.upcomingFeatures,
      appActorExperimentalFeatures: appTarget.experimentalFeatures,
      actorDependencyTargets: clientActorProjectionSet.dependencies.map {
        GeneratedActorDependencyTarget(
          moduleName: $0.moduleName,
          dependencyModuleNames: $0.dependencyModuleNames,
          clientImportedModuleNames: $0.clientImportedModuleNames,
          customConditions: $0.customConditions,
          upcomingFeatures: $0.upcomingFeatures,
          experimentalFeatures: $0.experimentalFeatures,
          bootstrapTypeName: $0.projection.manifest.bootstrapTypeName
        )
      }
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
      packageResolvedSnapshot,
      to: serverPackageDirectory
    )
    try packageResolvedSynchronizer.sync(
      packageResolvedSnapshot,
      to: devPackageDirectory
    )
    try packageResolvedSynchronizer.sync(
      packageResolvedSnapshot,
      to: wasmPackageDirectory,
      keepingIdentities: wasmPackageResolvedIdentities
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
      appPackageDirectory.path,
      O_RDONLY
    )
    guard descriptor >= 0 else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationLockOpenFailed(
        appPackageDirectory,
        errno
      )
    }
    defer {
      _ = close(descriptor)
    }

    guard flock(descriptor, LOCK_EX) == 0 else {
      throw SwiftWebGeneratedPackageMaterializerError.materializationLockFailed(
        appPackageDirectory,
        errno
      )
    }
    defer {
      _ = flock(descriptor, LOCK_UN)
    }

    return try body()
  }

  private func validateGeneratedWasmTargetNames(
    appProductName: String,
    wasmRuntimeTargetNames: [String],
    actorDependencyModuleNames: [String]
  ) throws {
    let fixedTargetNames = wasmRuntimeProfile.wasmSourceTargets(
      appProductName: appProductName
    )
    var targetNames = Set(fixedTargetNames + wasmRuntimeTargetNames)
    for moduleName in actorDependencyModuleNames {
      guard targetNames.insert(moduleName).inserted else {
        throw ActorGenerationError.schemaConflict(
          reason: "Actor dependency module \(moduleName) collides with a generated WASM target"
        )
      }
    }

    var declarationNames: Set<String> = [
      "appClientTarget",
      "swiftHTMLTarget",
      "swiftWebActorsTarget",
      "swiftWebStyleTarget",
      "swiftWebUIThemeTarget",
      "swiftWebUITarget",
      "cJavaScriptKitTarget",
      "javaScriptKitTarget",
      "cJavaScriptEventLoopTarget",
      "javaScriptEventLoopTarget",
      "actorSystemCoreTarget",
      "actorSystemRuntimeTarget",
      "swiftWebUIRuntimeTarget",
    ]
    for targetName in wasmRuntimeTargetNames {
      declarationNames.insert(
        GeneratedPackageNameFormatter.variableName(for: targetName)
      )
    }
    for moduleName in actorDependencyModuleNames {
      let declarationName = GeneratedPackageNameFormatter.variableName(
        for: moduleName
      )
      guard declarationNames.insert(declarationName).inserted else {
        throw ActorGenerationError.schemaConflict(
          reason: "Actor dependency module \(moduleName) collides with generated manifest declaration \(declarationName)"
        )
      }
    }
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

  private func makeActorProjection(
    appProductName: String,
    profile: ActorGenerationProfile,
    toolchain: SwiftWebHostSwiftToolchain,
    compilerTargetEnvironment: ActorGenerationTargetEnvironment,
    targetGraph: SwiftWebEvaluatedPackageTargetGraph
  ) throws -> SwiftWebActorProjectionSet {
    if profile == .embeddedHost {
      throw ActorGenerationError.invalidTargetEnvironment(
        reason: "SwiftWeb package materialization does not own an Embedded host target"
      )
    }
    guard let rootBuildTarget = targetGraph.target(named: appProductName) else {
      throw ActorGenerationError.schemaConflict(
        reason: "SwiftPM target graph has no application target named \(appProductName)"
      )
    }
    try rootBuildTarget.validateGeneratedProjectionCapabilities()
    guard FileManager.default.fileExists(atPath: rootBuildTarget.sourceDirectory.path) else {
      throw SwiftWebGeneratedPackageMaterializerError.clientSourceDirectoryNotFound(
        rootBuildTarget.sourceDirectory
      )
    }
    let allSourceFiles = try sourceFiles(
      rootBuildTarget.sourceFiles,
      relativeTo: rootBuildTarget.sourceDirectory,
      includingServerOnly: true
    )
    let projectedSourceFiles = try sourceFiles(
      rootBuildTarget.sourceFiles,
      relativeTo: rootBuildTarget.sourceDirectory,
      includingServerOnly: false
    )
    let sourceURLs = allSourceFiles.map(\.url)
    let directActorSchemaModules = try SwiftWebActorDependencySchemaDiscovery
      .directActorSchemaModuleNames(
        appModuleName: appProductName,
        targetGraph: targetGraph
      )
    let rootSourceEnvironment: ActorGenerationTargetEnvironment
    if profile == .nativeHost {
      rootSourceEnvironment = try compilerTargetEnvironment
        .addingAvailableModules(rootBuildTarget.directDependencyModuleNames)
        .addingBuildConditions(
        customConditions: rootBuildTarget.customConditions,
        features: rootBuildTarget.features
      )
    } else {
      rootSourceEnvironment = try compilerTargetEnvironment
        .addingAvailableModules(directActorSchemaModules)
        .addingBuildConditions(
          customConditions: rootBuildTarget.customConditions.union(
            SwiftWebActorProjection.generatedCustomConditions(
              profile: profile,
              role: .rootApplication
            )
          ),
          features: rootBuildTarget.features
        )
    }
    let dependencyBaseEnvironment = try compilerTargetEnvironment.addingBuildConditions(
      customConditions: SwiftWebActorProjection.generatedCustomConditions(
        profile: profile,
        role: .actorDependency
      )
    )
    let actors = try ActorSourceScanner.scan(
      sourceFiles: sourceURLs,
      moduleName: appProductName,
      includingActorSystemTypes: [
        "WebActorSystem",
        "SwiftWebActors.WebActorSystem",
      ],
      targetEnvironment: rootSourceEnvironment
    )
    let actorImportedModules = Set(actors.flatMap(\.imports))
    let actorBoundaryImportedModules = try ActorBoundaryImportAnalyzer.importedModules(
      actors: actors,
      sourceFiles: sourceURLs,
      moduleName: appProductName,
      targetEnvironment: rootSourceEnvironment
    )
    let clientSourceImportedModules: Set<String>
    let projectionImportedModules: Set<String>
    switch profile {
    case .nativeHost:
      clientSourceImportedModules = []
      projectionImportedModules = actorImportedModules
    case .standardClient, .embeddedHost, .embeddedClient:
      clientSourceImportedModules = try Self.importedModules(
        in: projectedSourceFiles,
        targetEnvironment: rootSourceEnvironment
      )
      projectionImportedModules = clientSourceImportedModules
        .union(actorImportedModules).union(
        try Self.referencedCanImportModules(in: projectedSourceFiles)
          .intersection(directActorSchemaModules)
      )
    }
    let dependencySchemas = try SwiftWebActorDependencySchemaDiscovery.discover(
      importedModules: actorBoundaryImportedModules,
      appModuleName: appProductName,
      targetGraph: targetGraph
    )
    let dependencyModules: [SwiftWebActorDependencyModule]
    switch profile {
    case .nativeHost:
      dependencyModules = []
    case .standardClient, .embeddedHost, .embeddedClient:
      dependencyModules = try SwiftWebActorDependencySchemaDiscovery.discoverModules(
        importedModules: projectionImportedModules,
        appModuleName: appProductName,
        targetGraph: targetGraph,
        targetEnvironment: dependencyBaseEnvironment
      )
    }
    let rootTargetEnvironment: ActorGenerationTargetEnvironment
    if profile == .nativeHost {
      rootTargetEnvironment = rootSourceEnvironment
    } else {
      rootTargetEnvironment = try compilerTargetEnvironment
        .addingAvailableModules(Set(dependencyModules.map { $0.schema.moduleName }))
        .addingBuildConditions(
          customConditions: rootBuildTarget.customConditions.union(
            SwiftWebActorProjection.generatedCustomConditions(
              profile: profile,
              role: .rootApplication
            )
          ),
          features: rootBuildTarget.features
        )
      let unavailableActiveImports = clientSourceImportedModules
        .subtracting(rootTargetEnvironment.availableModules)
        .subtracting([appProductName])
      guard unavailableActiveImports.isEmpty else {
        throw ActorGenerationError.schemaConflict(
          reason: "Application target \(appProductName) has active client imports unavailable to the generated target: \(unavailableActiveImports.sorted().joined(separator: ", "))"
        )
      }
    }
    if actors.isEmpty {
      let packageIdentity = GeneratedPackageNameFormatter.localPackageIdentity(
        for: appPackageDirectory
      )
      let schema = try ActorSchemaLockStore.load(
        from: appPackageDirectory.appendingPathComponent("ActorSchema.lock"),
        packageIdentity: packageIdentity,
        moduleName: appProductName
      )
      guard schema.actors.isEmpty else {
        throw ActorGenerationError.schemaConflict(
          reason: "Actor sources changed; run authoritative actor-system generation and commit ActorSchema.lock"
        )
      }
    }
    guard !actors.isEmpty || !dependencyModules.isEmpty else {
      return .empty
    }
    let reservedTargetNames: Set<String> = [
      appProductName,
      "ActorSystemCore",
      "ActorSystemDistributed",
      "ActorSystemEmbedded",
      "SwiftHTML",
      "SwiftWebActors",
      "SwiftWebStyle",
      "SwiftWebUITheme",
      "SwiftWebUI",
      "SwiftWebUIRuntime",
      "JavaScriptKit",
      "_CJavaScriptKit",
      "JavaScriptEventLoop",
      "_CJavaScriptEventLoop",
    ]
    if let collision = dependencyModules
      .map({ $0.schema.moduleName })
      .first(where: reservedTargetNames.contains) {
      throw ActorGenerationError.schemaConflict(
        reason: "Actor dependency module \(collision) collides with a generated WASM target"
      )
    }
    let dependencyVariableNames = dependencyModules.map {
      GeneratedPackageNameFormatter.variableName(for: $0.schema.moduleName)
    }
    guard Set(dependencyVariableNames).count == dependencyVariableNames.count else {
      throw ActorGenerationError.schemaConflict(
        reason: "Actor dependency module names collide in the generated WASM manifest"
      )
    }
    let expectedToolchainFingerprint = try ActorToolchainFingerprint.compute(
      swiftCompiler: toolchain.swiftCompilerURL
    )
    let rootProjection: SwiftWebActorProjection?
    if actors.isEmpty {
      rootProjection = nil
    } else {
      let sourceRoot = rootBuildTarget.sourceDirectory
      let outputDirectory = generatedPackageDirectory
        .appendingPathComponent("actor-system", isDirectory: true)
        .appendingPathComponent(profile.rawValue, isDirectory: true)
      let result = try ActorSystemCompiler.project(
        ActorSystemProjectionRequest(
          sourceFiles: sourceURLs,
          sourceRoot: sourceRoot,
          moduleName: appProductName,
          packageIdentity: GeneratedPackageNameFormatter.localPackageIdentity(
            for: appPackageDirectory
          ),
          profile: profile,
          schemaLockURL: appPackageDirectory.appendingPathComponent("ActorSchema.lock"),
          outputDirectory: outputDirectory,
          toolchainFingerprint: expectedToolchainFingerprint,
          expectedToolchainFingerprint: expectedToolchainFingerprint,
          dependencySchemas: dependencySchemas,
          distributedActorSystemTypeName: "SwiftWebActors.WebActorSystem",
          includedActorSystemTypeNames: [
            "WebActorSystem",
            "SwiftWebActors.WebActorSystem",
          ],
          targetEnvironment: rootTargetEnvironment
        )
      )
      rootProjection = try SwiftWebActorProjection(
        manifest: result.manifest,
        generatedDirectory: outputDirectory,
        targetEnvironment: rootTargetEnvironment
      )
    }
    let dependencySchemasByModule = Dictionary(
      uniqueKeysWithValues: dependencyModules.map { ($0.schema.moduleName, $0.schema) }
    )
    var dependencyProjections: [SwiftWebActorDependencyProjection] = []
    for module in dependencyModules {
      let moduleOutputDirectory = generatedPackageDirectory
        .appendingPathComponent("actor-system-dependencies", isDirectory: true)
        .appendingPathComponent(profile.rawValue, isDirectory: true)
        .appendingPathComponent(module.schema.moduleName, isDirectory: true)
      let moduleDependencies = module.dependencyModuleNames.compactMap {
        dependencySchemasByModule[$0]
      }
      let moduleResult = try ActorSystemCompiler.project(
        ActorSystemProjectionRequest(
          sourceFiles: module.sourceFiles,
          sourceRoot: module.sourceDirectory,
          moduleName: module.schema.moduleName,
          packageIdentity: module.schema.packageIdentity,
          profile: profile,
          schemaLockURL: module.schemaURL,
          outputDirectory: moduleOutputDirectory,
          toolchainFingerprint: expectedToolchainFingerprint,
          expectedToolchainFingerprint: expectedToolchainFingerprint,
          dependencySchemas: moduleDependencies,
          distributedActorSystemTypeName: "SwiftWebActors.WebActorSystem",
          includedActorSymbols: Set(module.schema.actors.map(\.sourceSymbol)),
          targetEnvironment: module.targetEnvironment
        )
      )
      dependencyProjections.append(
        SwiftWebActorDependencyProjection(
          moduleName: module.schema.moduleName,
          dependencyModuleNames: module.dependencyModuleNames,
          clientImportedModuleNames: module.clientImportedModuleNames,
          customConditions: module.customConditions,
          upcomingFeatures: module.upcomingFeatures,
          experimentalFeatures: module.experimentalFeatures,
          sourceDirectory: module.sourceDirectory,
          projection: try SwiftWebActorProjection(
            manifest: moduleResult.manifest,
            generatedDirectory: moduleOutputDirectory,
            targetEnvironment: module.targetEnvironment
          )
        )
      )
    }
    return SwiftWebActorProjectionSet(
      root: rootProjection,
      dependencies: dependencyProjections
    )
  }

  static func importedModules(
    in sourceFiles: [(url: URL, relativePath: String)],
    targetEnvironment: ActorGenerationTargetEnvironment
  ) throws -> Set<String> {
    var modules = Set<String>()
    for sourceFile in sourceFiles {
      let source = try String(contentsOf: sourceFile.url, encoding: .utf8)
      let syntax = Parser.parse(source: source)
      modules.formUnion(
        try ActorProfileConditionResolver.importedModules(
          in: syntax,
          environment: targetEnvironment,
          symbol: sourceFile.relativePath
        )
      )
    }
    return modules
  }

  private static func referencedCanImportModules(
    in sourceFiles: [(url: URL, relativePath: String)]
  ) throws -> Set<String> {
    var modules = Set<String>()
    for sourceFile in sourceFiles {
      let source = try String(contentsOf: sourceFile.url, encoding: .utf8)
      let syntax = Parser.parse(source: source)
      func collect(from syntax: Syntax) {
        if let clause = syntax.as(IfConfigClauseSyntax.self),
          let condition = clause.condition?.trimmedDescription {
          var remainder = condition[...]
          let marker = "canImport("
          while let range = remainder.range(of: marker) {
            let afterMarker = remainder[range.upperBound...]
            let module = afterMarker.prefix {
              $0.isLetter || $0.isNumber || $0 == "_"
            }
            if !module.isEmpty {
              modules.insert(String(module))
            }
            remainder = afterMarker.dropFirst(module.count)
          }
        }
        for child in syntax.children(viewMode: .sourceAccurate) {
          collect(from: child)
        }
      }
      collect(from: Syntax(syntax))
    }
    return modules
  }

  private func installNativeActorProjection(
    _ projection: SwiftWebActorProjection?,
    destinationSourceDirectory: URL
  ) throws {
    if let projection {
      try projection.installGeneratedSources(in: destinationSourceDirectory)
    } else {
      try SwiftWebActorProjection.clearGeneratedSources(
        in: destinationSourceDirectory
      )
    }
  }

  private func sourceFiles(
    _ sourceFiles: [URL],
    relativeTo directory: URL,
    includingServerOnly: Bool
  ) throws -> [(url: URL, relativePath: String)] {
    let rootPath = directory.standardizedFileURL.path
    let prefix = rootPath.hasSuffix("/") ? rootPath : rootPath + "/"
    var result: [(url: URL, relativePath: String)] = []
    for sourceFile in sourceFiles.sorted(by: { $0.path < $1.path }) {
      let sourcePath = sourceFile.standardizedFileURL.path
      guard sourcePath.hasPrefix(prefix) else {
        throw ActorGenerationError.schemaConflict(
          reason: "SwiftPM target source \(sourcePath) is outside declared target directory \(rootPath)"
        )
      }
      let relativePath = String(sourcePath.dropFirst(prefix.count))
      let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
      guard firstComponent != "ActorSystemGenerated" else {
        continue
      }
      guard includingServerOnly
        || !GeneratedSourcePathPolicy.isServerOnly(relativePath: relativePath) else {
        continue
      }
      result.append((sourceFile.standardizedFileURL, relativePath))
    }
    return result
  }

}
