import SwiftWebDevelopmentHooks
import SwiftWebWasmBuild
import Darwin
import Foundation
import SwiftHTML

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

  private var serverPackageDirectory: URL {
    generatedPackageDirectory
      .appendingPathComponent("server", isDirectory: true)
      .standardizedFileURL
  }

  private var devPackageDirectory: URL {
    generatedPackageDirectory
      .appendingPathComponent("dev", isDirectory: true)
      .standardizedFileURL
  }

  private var wasmPackageDirectory: URL {
    generatedPackageDirectory
      .appendingPathComponent("wasm", isDirectory: true)
      .standardizedFileURL
  }

  private var developmentServerProductName: String {
    "\(serverProductName)-dev"
  }

  private static let wasmPackageResolvedIdentities: Set<String> = [
    "swift-actor-runtime"
  ]

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
    try optionalSwiftWebPackageDirectory(packageDirectoryContainingThisFile().standardizedFileURL)
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
    let wasmRuntimeTargets = wasmRuntimeTargets(
      appProductName: appProductName,
      for: clientComponents
    )
    let wasmRuntimeTargetNames = wasmRuntimeTargets.map(\.targetName)
    let wasmProductNames = wasmRuntimeTargetNames.map(Self.productName(forWasmRuntimeTarget:))
    let wasmRuntimes = wasmRuntimeTargets.map { target in
      SwiftWebGeneratedWasmRuntime(
        packageDirectory: wasmPackageDirectory,
        targetName: target.targetName,
        productName: Self.productName(forWasmRuntimeTarget: target.targetName),
        componentTypeNames: target.componentTypeNames,
        bundleID: target.bundleID,
        assetPath: Self.assetPath(forWasmRuntimeTarget: target.targetName),
        linkMode: target.linkMode
      )
    }

    try removeLegacyMaterializationLockFile()
    try removeLegacySinglePackageLayout()
    try writeServerGeneratedSources(
      appProductName: appProductName,
      wasmRuntimeTargets: wasmRuntimeTargets
    )
    try writeDevGeneratedSources(
      appProductName: appProductName,
      wasmRuntimeTargets: wasmRuntimeTargets
    )
    try writeWasmGeneratedSources(
      appProductName: appProductName,
      wasmRuntimeTargets: wasmRuntimeTargets
    )
    switch wasmRuntimeProfile {
    case .standard:
      try copyClientSources(appProductName: appProductName, to: wasmPackageDirectory)
      try copySwiftHTMLRuntimeSources(
        swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
        swiftWebPackageDirectory: swiftWebPackageDirectory,
        to: wasmPackageDirectory
      )
      try copyClientRuntimeSources(from: swiftWebPackageDirectory, to: wasmPackageDirectory)
    case .embedded:
      try copySwiftHTMLClientRuntimeSources(
        swiftHTMLPackageDirectory: swiftHTMLPackageDirectory,
        swiftWebPackageDirectory: swiftWebPackageDirectory,
        to: wasmPackageDirectory
      )
    }
    try copyJavaScriptKitRuntimeSources(
      swiftWebPackageDirectory: swiftWebPackageDirectory,
      to: wasmPackageDirectory
    )
    try removeStaleWasmSourceTargets(
      keeping: Set(
        wasmRuntimeProfile.wasmSourceTargets(appProductName: appProductName)
          + wasmRuntimeTargetNames
      )
    )
    let serverPackageSwiftContents = serverPackageSwift(
      appPackageName: packageName,
      appPackageDependencyName: Self.localPackageIdentity(for: appPackageDirectory),
      appProductName: appProductName,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    let devPackageSwiftContents = devPackageSwift(
      appPackageName: packageName,
      appPackageDependencyName: Self.localPackageIdentity(for: appPackageDirectory),
      appProductName: appProductName,
      developmentServerProductName: developmentServerProductName,
      devProductName: devProductName,
      swiftWebPackageDirectory: swiftWebPackageDirectory
    )
    let wasmPackageSwiftContents = wasmPackageSwift(
      appPackageName: packageName,
      appProductName: appProductName,
      wasmRuntimeTargetNames: wasmRuntimeTargetNames,
      actorRuntimeDependencyDeclaration: try actorRuntimeDependencyDeclaration(
        fallbackPackageDirectory: swiftWebPackageDirectory
      ),
      runtimeProfile: wasmRuntimeProfile
    )
    try removeGeneratedBuildDirectoryIfPackageChanged(
      in: serverPackageDirectory,
      nextPackageSwift: serverPackageSwiftContents
    )
    try removeGeneratedBuildDirectoryIfPackageChanged(
      in: devPackageDirectory,
      nextPackageSwift: devPackageSwiftContents
    )
    try removeGeneratedBuildDirectoryIfPackageChanged(
      in: wasmPackageDirectory,
      nextPackageSwift: wasmPackageSwiftContents
    )
    try writeIfChanged(
      serverPackageSwiftContents,
      to: serverPackageDirectory.appendingPathComponent("Package.swift")
    )
    try writeIfChanged(
      devPackageSwiftContents,
      to: devPackageDirectory.appendingPathComponent("Package.swift")
    )
    try writeIfChanged(
      wasmPackageSwiftContents,
      to: wasmPackageDirectory.appendingPathComponent("Package.swift")
    )
    try syncPackageResolved(
      to: serverPackageDirectory,
      fallbackPackageDirectory: swiftWebPackageDirectory
    )
    try syncPackageResolved(
      to: devPackageDirectory,
      fallbackPackageDirectory: swiftWebPackageDirectory
    )
    try syncPackageResolved(
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
      try removeGeneratedItem(at: lockFile)
    }
  }

  private func removeLegacySinglePackageLayout() throws {
    for name in ["Package.swift", "Package.resolved"] {
      let url = generatedPackageDirectory.appendingPathComponent(name)
      if FileManager.default.fileExists(atPath: url.path) {
        try removeGeneratedItem(at: url)
      }
    }

    for name in ["Sources", ".build"] {
      let url = generatedPackageDirectory.appendingPathComponent(name, isDirectory: true)
      if FileManager.default.fileExists(atPath: url.path) {
        try removeGeneratedItem(at: url)
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
      guard !isServerOnly(relativePath: relativeChildPath) else {
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

  private static func resolvedBundleID(
    for component: ClientComponentDeclaration
  ) -> ClientBundleID? {
    switch component.bundlePolicy {
    case .main:
      if component.loadPolicy == .eager {
        return nil
      }
      return ClientBundleID("component-\(stableHashHex(component.typeName))")
    case .component:
      return ClientBundleID("component-\(stableHashHex(component.typeName))")
    case .named(let name):
      return ClientBundleID("named-\(stableBundleName(name))")
    case .shared(let name):
      return ClientBundleID("shared-\(stableBundleName(name))")
    }
  }

  private func wasmRuntimeTargets(
    appProductName: String,
    for clientComponents: [ClientComponentDeclaration]
  ) -> [WasmRuntimeTargetDeclaration] {
    guard !clientComponents.isEmpty else {
      return []
    }

    let mainTargetName = "\(appProductName)WasmRuntime"
    let mainBundleID = ClientBundleID(Self.productName(forWasmRuntimeTarget: mainTargetName))
    let mainComponents = clientComponents.filter { Self.resolvedBundleID(for: $0) == nil }
    var targets: [WasmRuntimeTargetDeclaration] = [
      WasmRuntimeTargetDeclaration(
        targetName: mainTargetName,
        bundleID: mainBundleID,
        componentTypeNames: Self.uniqueTypeNames(
          mainComponents.map(\.typeName)),
        actorContracts: Self.actorContracts(for: mainComponents),
        linkMode: .standalone
      )
    ]

    let splitComponents = Dictionary(
      grouping: clientComponents.compactMap {
        component -> (ClientBundleID, ClientComponentDeclaration)? in
        guard let bundleID = Self.resolvedBundleID(for: component) else {
          return nil
        }
        return (bundleID, component)
      }
    ) { item in
      item.0
    }

    if wasmSplitBuildStrategy == .coalescedPolicyBundles {
      let splitPairs = splitComponents.values
        .flatMap { $0.map(\.1) }
      for loadPolicy in Self.coalescedPolicyOrder {
        let policyPairs =
          splitPairs
          .filter { $0.loadPolicy == loadPolicy }
          .sorted { left, right in
            left.typeName < right.typeName
          }
        guard !policyPairs.isEmpty else {
          continue
        }

        let targetName =
          "\(appProductName)\(Self.wasmRuntimeTargetSuffix(for: loadPolicy))WasmRuntime"
        let policyBundleGroups = Dictionary(grouping: policyPairs) { component in
          Self.resolvedBundleID(for: component)
            ?? ClientBundleID(Self.productName(forWasmRuntimeTarget: targetName))
        }
        targets.append(
          WasmRuntimeTargetDeclaration(
            targetName: targetName,
            bundleID: ClientBundleID(Self.productName(forWasmRuntimeTarget: targetName)),
            componentTypeNames: Self.uniqueTypeNames(policyPairs.map(\.typeName)),
            actorContracts: Self.actorContracts(for: policyPairs),
            bundleArtifacts: policyBundleGroups.keys.sorted().map { bundleID in
              let components = policyBundleGroups[bundleID, default: []].sorted { left, right in
                left.typeName < right.typeName
              }
              return WasmRuntimeBundleArtifactDeclaration(
                bundleID: bundleID,
                componentTypeNames: Self.uniqueTypeNames(components.map(\.typeName))
              )
            },
            linkMode: .coalescedStaticFallback
          ))
      }
      return targets
    }

    var usedTargetNames = Set<String>()
    usedTargetNames.insert(mainTargetName)
    for bundleID in splitComponents.keys.sorted() {
      let components = splitComponents[bundleID, default: []].map(\.1).sorted { left, right in
        left.typeName < right.typeName
      }
      var targetName = Self.wasmRuntimeTargetName(forBundleID: bundleID)
      var suffix = 2
      while !usedTargetNames.insert(targetName).inserted {
        targetName = "\(Self.wasmRuntimeTargetName(forBundleID: bundleID))\(suffix)"
        suffix += 1
      }
      targets.append(
        WasmRuntimeTargetDeclaration(
          targetName: targetName,
          bundleID: bundleID,
          componentTypeNames: Self.uniqueTypeNames(components.map(\.typeName)),
          actorContracts: Self.actorContracts(for: components),
          bundleArtifacts: [
            WasmRuntimeBundleArtifactDeclaration(
              bundleID: bundleID,
              componentTypeNames: Self.uniqueTypeNames(components.map(\.typeName))
            )
          ],
          linkMode: .standalone
        ))
    }
    return targets
  }

  private func removeGeneratedBuildDirectoryIfPackageChanged(
    in packageDirectory: URL,
    nextPackageSwift: String
  ) throws {
    let packageFile = packageDirectory.appendingPathComponent("Package.swift")
    guard FileManager.default.fileExists(atPath: packageFile.path) else {
      return
    }

    let currentPackageSwift = try String(contentsOf: packageFile, encoding: .utf8)
    guard currentPackageSwift != nextPackageSwift else {
      return
    }

    let buildDirectory = packageDirectory.appendingPathComponent(".build", isDirectory: true)
    if FileManager.default.fileExists(atPath: buildDirectory.path) {
      try removeGeneratedItem(at: buildDirectory)
    }
  }

  private func syncPackageResolved(
    to packageDirectory: URL,
    fallbackPackageDirectory: URL? = nil,
    keepingIdentities identities: Set<String>? = nil
  ) throws {
    let destinationURL = packageDirectory.appendingPathComponent("Package.resolved")

    if let sourceURL = packageResolvedSourceURL(fallbackPackageDirectory: fallbackPackageDirectory)
    {
      if let identities {
        let data = try filteredPackageResolvedData(from: sourceURL, keepingIdentities: identities)
        try writeDataIfChanged(data, to: destinationURL)
      } else {
        let data = try Data(contentsOf: sourceURL)
        try writeDataIfChanged(data, to: destinationURL)
      }
    } else if FileManager.default.fileExists(atPath: destinationURL.path) {
      try FileManager.default.removeItem(at: destinationURL)
    }
  }

  private func packageResolvedSourceURL(fallbackPackageDirectory: URL?) -> URL? {
    let appPackageResolved = appPackageDirectory.appendingPathComponent("Package.resolved")
    if FileManager.default.fileExists(atPath: appPackageResolved.path) {
      return appPackageResolved
    }

    guard let fallbackPackageDirectory else {
      return nil
    }

    let fallbackPackageResolved = fallbackPackageDirectory.appendingPathComponent(
      "Package.resolved"
    )
    if FileManager.default.fileExists(atPath: fallbackPackageResolved.path) {
      return fallbackPackageResolved
    }

    return nil
  }

  private func actorRuntimeDependencyDeclaration(
    fallbackPackageDirectory: URL? = nil
  ) throws -> String {
    guard
      let sourceURL = packageResolvedSourceURL(fallbackPackageDirectory: fallbackPackageDirectory)
    else {
      return fallbackActorRuntimeDependencyDeclaration
    }

    let data = try Data(contentsOf: sourceURL)
    let packageResolved = try JSONDecoder().decode(PackageResolvedFile.self, from: data)
    guard
      let pin = packageResolved.pins.first(where: {
        $0.identity.lowercased() == "swift-actor-runtime"
      })
    else {
      return fallbackActorRuntimeDependencyDeclaration
    }

    let location = pin.location ?? "https://github.com/1amageek/swift-actor-runtime.git"
    if let version = pin.state.version {
      return
        #".package(url: "\#(Self.swiftStringLiteral(location))", exact: "\#(Self.swiftStringLiteral(version))")"#
    }
    if let revision = pin.state.revision {
      return
        #".package(url: "\#(Self.swiftStringLiteral(location))", revision: "\#(Self.swiftStringLiteral(revision))")"#
    }
    return fallbackActorRuntimeDependencyDeclaration
  }

  private var fallbackActorRuntimeDependencyDeclaration: String {
    #".package(url: "https://github.com/1amageek/swift-actor-runtime.git", from: "0.6.0")"#
  }

  private func filteredPackageResolvedData(
    from sourceURL: URL,
    keepingIdentities identities: Set<String>
  ) throws -> Data {
    let data = try Data(contentsOf: sourceURL)
    guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
      throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(sourceURL)
    }
    guard let pins = object["pins"] as? [[String: Any]] else {
      throw SwiftWebGeneratedPackageMaterializerError.invalidPackageResolved(sourceURL)
    }

    let filteredPins = pins.filter { pin in
      guard let identity = pin["identity"] as? String else {
        return false
      }
      return identities.contains(identity.lowercased())
    }
    let filteredObject: [String: Any] = [
      "pins": filteredPins,
      "version": object["version"] ?? 3,
    ]
    return try JSONSerialization.data(
      withJSONObject: filteredObject,
      options: [.prettyPrinted, .sortedKeys]
    )
  }

  private func writeServerGeneratedSources(
    appProductName: String,
    wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
  ) throws {
    try write(
      serverLauncherSwift(
        appProductName: appProductName,
        wasmRuntimeTargets: wasmRuntimeTargets,
        installsDevelopmentHooks: false
      ),
      to: "Sources/AppServerLauncher/ServerLauncher.swift",
      in: serverPackageDirectory
    )
  }

  private func writeDevGeneratedSources(
    appProductName: String,
    wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
  ) throws {
    try write(
      devLauncherSwift(appProductName: appProductName),
      to: "Sources/SwiftWebDevLauncher/DevLauncher.swift",
      in: devPackageDirectory
    )
    try write(
      serverLauncherSwift(
        appProductName: appProductName,
        wasmRuntimeTargets: wasmRuntimeTargets,
        installsDevelopmentHooks: true
      ),
      to: "Sources/AppDevelopmentServerLauncher/ServerLauncher.swift",
      in: devPackageDirectory
    )
  }

  private func writeWasmGeneratedSources(
    appProductName: String,
    wasmRuntimeTargets: [WasmRuntimeTargetDeclaration]
  ) throws {
    for target in wasmRuntimeTargets {
      try write(
        wasmEntrypointSwift(appProductName: appProductName, target: target),
        to: "Sources/\(target.targetName)/\(target.targetName).swift",
        in: wasmPackageDirectory
      )
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

    try mirrorDirectoryContents(
      from: sourceDirectory,
      to: destinationDirectory,
      relativePath: "",
      shouldSkip: isServerOnly(relativePath:)
    )
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
    try mirrorDirectoryContents(
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
    try mirrorDirectoryContents(
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
    let compiledPackageDirectory = packageDirectoryContainingThisFile()
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
    let compiledPackageDirectory = packageDirectoryContainingThisFile()
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

  private func copyClientRuntimeSources(
    from swiftWebPackageDirectory: URL, to packageDirectory: URL
  ) throws {
    for targetName in ["SwiftWebStyle", "SwiftWebActors", "SwiftWebUI", "SwiftWebUIRuntime"] {
      let sourceDirectory =
        swiftWebPackageDirectory
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(targetName, isDirectory: true)
      let destinationDirectory =
        packageDirectory
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(targetName, isDirectory: true)
      try FileManager.default.createDirectory(
        at: destinationDirectory,
        withIntermediateDirectories: true
      )
      try mirrorDirectoryContents(
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
    try mirrorDirectoryContents(
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
    try mirrorDirectoryContents(
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
    let compiledPackageDirectory = packageDirectoryContainingThisFile()
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

  private static func packageDirectoryContainingThisFile() -> URL {
    var directory = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
    while directory.lastPathComponent != "Sources" && directory.path != "/" {
      directory.deleteLastPathComponent()
    }
    if directory.lastPathComponent == "Sources" {
      return directory.deletingLastPathComponent()
    }
    return URL(fileURLWithPath: #filePath).deletingLastPathComponent()
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

  private func mirrorDirectoryContents(
    from sourceDirectory: URL,
    to destinationDirectory: URL,
    relativePath: String,
    shouldSkip: (String) -> Bool
  ) throws {
    let children = try FileManager.default.contentsOfDirectory(
      at: sourceDirectory,
      includingPropertiesForKeys: [.isDirectoryKey],
      options: [.skipsHiddenFiles]
    )

    var expectedNames = Set<String>()
    for child in children {
      let relativeChildPath =
        relativePath.isEmpty
        ? child.lastPathComponent
        : "\(relativePath)/\(child.lastPathComponent)"
      guard !shouldSkip(relativeChildPath) else {
        continue
      }
      expectedNames.insert(child.lastPathComponent)

      let destination = destinationDirectory.appendingPathComponent(child.lastPathComponent)
      let values = try child.resourceValues(forKeys: [.isDirectoryKey])
      if values.isDirectory == true {
        try FileManager.default.createDirectory(
          at: destination,
          withIntermediateDirectories: true
        )
        try mirrorDirectoryContents(
          from: child,
          to: destination,
          relativePath: relativeChildPath,
          shouldSkip: shouldSkip
        )
      } else {
        try copyFileIfChanged(from: child, to: destination)
      }
    }

    let destinationChildren = try FileManager.default.contentsOfDirectory(
      at: destinationDirectory,
      includingPropertiesForKeys: nil,
      options: [.skipsHiddenFiles]
    )
    for child in destinationChildren where !expectedNames.contains(child.lastPathComponent) {
      try removeGeneratedItem(at: child)
    }
  }

  private func copyFileIfChanged(from source: URL, to destination: URL) throws {
    if FileManager.default.fileExists(atPath: destination.path) {
      let sourceData = try Data(contentsOf: source)
      try writeDataIfChanged(sourceData, to: destination)
      return
    }
    try FileManager.default.copyItem(at: source, to: destination)
  }

  private func writeDataIfChanged(_ data: Data, to url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let current = try Data(contentsOf: url)
      if current == data {
        return
      }
    }
    try data.write(to: url, options: [.atomic])
  }

  private func removeStaleWasmSourceTargets(keeping names: Set<String>) throws {
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
      try removeGeneratedItem(at: child)
    }
  }

  private func removeGeneratedItem(at url: URL) throws {
    do {
      try FileManager.default.removeItem(at: url)
    } catch {
      try removeGeneratedItemWithRM(at: url, originalError: error)
    }
  }

  private func removeGeneratedItemWithRM(at url: URL, originalError: any Error) throws {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: "/bin/rm")
    process.arguments = ["-rf", url.path]
    process.standardOutput = FileHandle.standardOutput
    process.standardError = FileHandle.standardError

    try process.run()
    process.waitUntilExit()

    if process.terminationStatus != 0 || FileManager.default.fileExists(atPath: url.path) {
      throw originalError
    }
  }

  private func isServerOnly(relativePath: String) -> Bool {
    let firstComponent = relativePath.split(separator: "/", maxSplits: 1).first.map(String.init)
    if firstComponent == "Actions" || firstComponent == "Routes" {
      return true
    }
    return relativePath == "App.swift"
  }

  private func write(_ contents: String, to relativePath: String, in packageDirectory: URL) throws {
    let url = packageDirectory.appendingPathComponent(relativePath)
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try writeIfChanged(contents, to: url)
  }

  private func writeIfChanged(_ contents: String, to url: URL) throws {
    if FileManager.default.fileExists(atPath: url.path) {
      let current = try String(contentsOf: url, encoding: .utf8)
      if current == contents {
        return
      }
    }
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  private func serverLauncherSwift(
    appProductName: String,
    wasmRuntimeTargets: [WasmRuntimeTargetDeclaration],
    installsDevelopmentHooks: Bool
  ) -> String {
    let developmentImport =
      installsDevelopmentHooks
      ? "\nimport SwiftWebDevelopmentHooks"
      : ""
    let developmentInstall =
      installsDevelopmentHooks
      ? "\n        SwiftWebDevConsoleLogging.bootstrap()\n        await SwiftWebDevelopmentHooksRuntime.install()\n"
      : ""
    guard let runtimeTarget = wasmRuntimeTargets.first else {
      return """
        import \(appProductName)
        import SwiftWebVapor\(developmentImport)

        @main
        struct AppServerLauncher {
            static func main() async throws {
        \(developmentInstall)        try await \(appProductName).run()
            }
        }
        """
    }

    let productName = Self.productName(forWasmRuntimeTarget: runtimeTarget.targetName)
    let assetPath = Self.assetPath(forWasmRuntimeTarget: runtimeTarget.targetName)
    let wasmPackageManifestPath =
      wasmPackageDirectory
      .appendingPathComponent("Package.swift")
      .path
    let additionalBundles = wasmRuntimeTargets.dropFirst().flatMap { target in
      target.bundleArtifacts.map { bundleArtifact in
        let componentTypeNames = bundleArtifact.componentTypeNames
          .map { "\"\(Self.swiftStringLiteral($0))\"" }
          .joined(separator: ", ")
        return """
                              ClientRuntimeBundleArtifact(
                                  id: "\(bundleArtifact.bundleID.rawValue)",
                                  componentTypeNames: [\(componentTypeNames)],
                                  assetPath: "\(Self.assetPath(forWasmRuntimeTarget: target.targetName))",
                                  artifact: SwiftPMWasmArtifact.location(
                                      anchorFile: "\(Self.swiftStringLiteral(wasmPackageManifestPath))",
                                      target: "\(target.targetName)",
                                      artifactName: "\(Self.productName(forWasmRuntimeTarget: target.targetName))",
                                      scratchDirectory: wasmScratchDirectory
                                  )
                              )
          """
      }
    }
    .joined(separator: ",\n")
    let additionalBundlesArgument =
      additionalBundles.isEmpty
      ? "additionalBundles: []"
      : "additionalBundles: [\n\(additionalBundles)\n                            ]"
    return """
      import \(appProductName)
      import Foundation
      import SwiftWebVapor\(developmentImport)

      @main
      struct AppServerLauncher {
          static func main() async throws {
      \(developmentInstall)        let wasmScratchDirectory = ProcessInfo.processInfo.environment["SWIFTWEB_WASM_SCRATCH_PATH"].map {
                  URL(fileURLWithPath: $0, isDirectory: true)
              }

              try await \(appProductName).run(
                  clientRuntime: .wasm(
                      id: "\(productName)",
                      assetPath: "\(assetPath)",
                      artifact: SwiftPMWasmArtifact.location(
                          anchorFile: "\(Self.swiftStringLiteral(wasmPackageManifestPath))",
                          target: "\(runtimeTarget.targetName)",
                          artifactName: "\(productName)",
                          scratchDirectory: wasmScratchDirectory
                      ),
                      \(additionalBundlesArgument),
                      metricsMode: .detailed
                  )
              )
          }
      }
      """
  }

  private func devLauncherSwift(appProductName: String) -> String {
    """
    import \(appProductName)
    import Foundation
    import SwiftWebDevelopment

    @main
    struct SwiftWebDevLauncher {
        static func main() async throws {
            SwiftWebDevConsoleLogging.bootstrap()

            let environment = ProcessInfo.processInfo.environment
            let appPackagePath = environment["SWIFT_WEB_APP_PACKAGE_PATH"] ?? "\(Self.swiftStringLiteral(appPackageDirectory.path))"
            let product = environment["SWIFT_WEB_DEV_PRODUCT"] ?? "\(Self.swiftStringLiteral(serverProductName))"
            let host = environment["SWIFT_WEB_DEV_HOST"] ?? "127.0.0.1"
            let port = try integerEnvironment("SWIFT_WEB_DEV_PORT", in: environment, defaultValue: 3000)

            let configuration = SwiftWebDevRuntimeConfiguration(
                packageDirectory: URL(fileURLWithPath: appPackagePath),
                product: product,
                host: host,
                port: port
            )
            try await SwiftWebDevRuntime(configuration: configuration).run()
        }

        private static func integerEnvironment(
            _ key: String,
            in environment: [String: String],
            defaultValue: Int
        ) throws -> Int {
            guard let rawValue = environment[key] else {
                return defaultValue
            }
            guard let value = Int(rawValue) else {
                throw SwiftWebDevLauncherError.invalidIntegerEnvironment(key: key, value: rawValue)
            }
            return value
        }
    }

    enum SwiftWebDevLauncherError: Error, CustomStringConvertible {
        case invalidIntegerEnvironment(key: String, value: String)

        var description: String {
            switch self {
            case .invalidIntegerEnvironment(let key, let value):
                return "\\(key) must be an integer, but got \\(value)"
            }
        }
    }
    """
  }

  private func serverPackageSwift(
    appPackageName: String,
    appPackageDependencyName: String,
    appProductName: String,
    swiftWebPackageDirectory: URL
  ) -> String {
    let appDependencyPath = Self.relativePath(
      from: serverPackageDirectory,
      to: appPackageDirectory
    )
    let swiftWebDependencyPath = Self.relativePath(
      from: serverPackageDirectory,
      to: swiftWebPackageDirectory
    )
    return """
      // swift-tools-version: 6.3

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]

      let appServerTarget = Target.executableTarget(
          name: "AppServerLauncher",
          dependencies: [
              .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
              .product(name: "SwiftWebVapor", package: "swift-web"),
          ],
          path: "Sources/AppServerLauncher",
          swiftSettings: swiftSettings
      )

      let package = Package(
          name: "\(appPackageName)ServerGenerated",
          platforms: [
              .macOS("26.2"),
          ],
          products: [
              .executable(name: "\(serverProductName)", targets: ["AppServerLauncher"]),
          ],
          dependencies: [
              .package(path: "\(Self.swiftStringLiteral(appDependencyPath))"),
              .package(path: "\(Self.swiftStringLiteral(swiftWebDependencyPath))"),
          ],
          targets: [
              appServerTarget,
          ],
          swiftLanguageModes: [.v6]
      )
      """
  }

  private func devPackageSwift(
    appPackageName: String,
    appPackageDependencyName: String,
    appProductName: String,
    developmentServerProductName: String,
    devProductName: String,
    swiftWebPackageDirectory: URL
  ) -> String {
    let appDependencyPath = Self.relativePath(
      from: devPackageDirectory,
      to: appPackageDirectory
    )
    let swiftWebDependencyPath = Self.relativePath(
      from: devPackageDirectory,
      to: swiftWebPackageDirectory
    )
    return """
      // swift-tools-version: 6.3

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]

      let swiftWebDevLauncherTarget = Target.executableTarget(
          name: "SwiftWebDevLauncher",
          dependencies: [
              .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
              .product(name: "SwiftWebDevelopment", package: "swift-web"),
          ],
          path: "Sources/SwiftWebDevLauncher",
          swiftSettings: swiftSettings
      )

      let appDevelopmentServerTarget = Target.executableTarget(
          name: "AppDevelopmentServerLauncher",
          dependencies: [
              .product(name: "\(appProductName)", package: "\(appPackageDependencyName)"),
              .product(name: "SwiftWebVapor", package: "swift-web"),
              .product(name: "SwiftWebDevelopmentHooks", package: "swift-web"),
          ],
          path: "Sources/AppDevelopmentServerLauncher",
          swiftSettings: swiftSettings
      )

      let package = Package(
          name: "\(appPackageName)DevGenerated",
          platforms: [
              .macOS("26.2"),
          ],
          products: [
              .executable(name: "\(devProductName)", targets: ["SwiftWebDevLauncher"]),
              .executable(name: "\(developmentServerProductName)", targets: ["AppDevelopmentServerLauncher"]),
          ],
          dependencies: [
              .package(path: "\(Self.swiftStringLiteral(appDependencyPath))"),
              .package(path: "\(Self.swiftStringLiteral(swiftWebDependencyPath))"),
          ],
          targets: [
              swiftWebDevLauncherTarget,
              appDevelopmentServerTarget,
          ],
          swiftLanguageModes: [.v6]
      )
      """
  }

  private func wasmPackageSwift(
    appPackageName: String,
    appProductName: String,
    wasmRuntimeTargetNames: [String],
    actorRuntimeDependencyDeclaration: String,
    runtimeProfile: SwiftWebWasmRuntimeProfile
  ) -> String {
    switch runtimeProfile {
    case .standard:
      return standardWasmPackageSwift(
        appPackageName: appPackageName,
        appProductName: appProductName,
        wasmRuntimeTargetNames: wasmRuntimeTargetNames,
        actorRuntimeDependencyDeclaration: actorRuntimeDependencyDeclaration
      )
    case .embedded:
      return embeddedWasmPackageSwift(
        appPackageName: appPackageName,
        wasmRuntimeTargetNames: wasmRuntimeTargetNames
      )
    }
  }

  private func standardWasmPackageSwift(
    appPackageName: String,
    appProductName: String,
    wasmRuntimeTargetNames: [String],
    actorRuntimeDependencyDeclaration: String
  ) -> String {
    wasmPackageSwiftContents(
      appPackageName: appPackageName,
      wasmRuntimeTargetNames: wasmRuntimeTargetNames,
      targetDeclarations: wasmRuntimeTargetNames.map { targetName in
        standardWasmRuntimeTargetDeclaration(targetName: targetName, appProductName: appProductName)
      },
      supportTargetDeclarations: [
        """
        let appClientTarget = Target.target(
            name: "\(appProductName)",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebUI",
                "SwiftWebUIRuntime",
            ],
            path: "Sources/\(appProductName)",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftHTMLTarget = Target.target(
            name: "SwiftHTML",
            path: "Sources/SwiftHTML",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebActorsTarget = Target.target(
            name: "SwiftWebActors",
            dependencies: [
                .product(name: "ActorRuntime", package: "swift-actor-runtime"),
            ],
            path: "Sources/SwiftWebActors",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebStyleTarget = Target.target(
            name: "SwiftWebStyle",
            dependencies: [
                "SwiftHTML",
            ],
            path: "Sources/SwiftWebStyle",
            swiftSettings: swiftSettings
        )
        """,
        """
        let swiftWebUITarget = Target.target(
            name: "SwiftWebUI",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebUI",
            swiftSettings: swiftSettings
        )
        """,
        javaScriptKitTargetDeclarations(),
        """
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                "SwiftHTML",
                "JavaScriptKit",
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
            path: "Sources/SwiftWebUIRuntime",
            swiftSettings: swiftSettings
        )
        """,
      ],
      supportTargets: [
        "cJavaScriptKitTarget",
        "javaScriptKitTarget",
        "swiftHTMLTarget",
        "swiftWebActorsTarget",
        "swiftWebStyleTarget",
        "swiftWebUITarget",
        "swiftWebUIRuntimeTarget",
        "appClientTarget",
      ],
      dependencies: [actorRuntimeDependencyDeclaration]
    )
  }

  private func embeddedWasmPackageSwift(
    appPackageName: String,
    wasmRuntimeTargetNames: [String]
  ) -> String {
    wasmPackageSwiftContents(
      appPackageName: appPackageName,
      wasmRuntimeTargetNames: wasmRuntimeTargetNames,
      targetDeclarations: wasmRuntimeTargetNames.map(embeddedWasmRuntimeTargetDeclaration),
      supportTargetDeclarations: [
        javaScriptKitTargetDeclarations(),
        """
        let swiftHTMLClientRuntimeTarget = Target.target(
            name: "SwiftHTMLClientRuntime",
            path: "Sources/SwiftHTMLClientRuntime",
            swiftSettings: swiftSettings
        )
        """,
      ],
      supportTargets: [
        "cJavaScriptKitTarget",
        "javaScriptKitTarget",
        "swiftHTMLClientRuntimeTarget",
      ],
      dependencies: []
    )
  }

  private func wasmPackageSwiftContents(
    appPackageName: String,
    wasmRuntimeTargetNames: [String],
    targetDeclarations: [String],
    supportTargetDeclarations: [String],
    supportTargets: [String],
    dependencies: [String]
  ) -> String {
    let wasmTargetDeclarations = targetDeclarations.joined(separator: "\n\n")
    let wasmProductDeclarations =
      wasmRuntimeTargetNames
      .map { targetName in
        ".executable(name: \"\(Self.productName(forWasmRuntimeTarget: targetName))\", targets: [\"\(targetName)\"])"
      }
      .joined(separator: ",\n        ")
    let wasmTargets = (supportTargets + wasmRuntimeTargetNames.map(Self.variableName(for:)))
      .map { "        \($0)" }
      .joined(separator: ",\n")
    let dependencyDeclarations =
      dependencies.isEmpty
      ? ""
      : "\n          \(dependencies.joined(separator: ",\n          ")),\n      "
    let supportDeclarations = supportTargetDeclarations.joined(separator: "\n\n")
    return """
      // swift-tools-version: 6.3

      import PackageDescription

      let swiftSettings: [SwiftSetting] = [
          .enableUpcomingFeature("ApproachableConcurrency"),
      ]
      let wasmSwiftSettings: [SwiftSetting] = swiftSettings + [
          .enableExperimentalFeature("Extern"),
          .unsafeFlags(["-Xclang-linker", "-mexec-model=reactor"]),
      ]
      let wasmLinkerSettings: [LinkerSetting] = [
          .unsafeFlags([
              // The hydration/render walk recurses through the component tree; the
              // default wasm stack (1 MB) overflows on deep trees and traps with
              // "memory access out of bounds". Give it generous headroom.
              "-Xlinker", "-z", "-Xlinker", "stack-size=16777216",
              "-Xlinker", "--export=swiftweb_alloc",
              "-Xlinker", "--export=swiftweb_dealloc",
              "-Xlinker", "--export=swiftweb_bootstrap",
              "-Xlinker", "--export=swiftweb_dispatch_event",
              "-Xlinker", "--export=swiftweb_snapshot_state",
              "-Xlinker", "--export=swiftweb_restore_state",
              "-Xlinker", "--export=swiftweb_response_ptr",
              "-Xlinker", "--export=swiftweb_response_len",
              "-Xlinker", "--export=swiftweb_response_free",
          ]),
      ]

      \(supportDeclarations)

      \(wasmTargetDeclarations)

      let package = Package(
          name: "\(appPackageName)WasmGenerated",
          platforms: [
              .macOS("26.2"),
          ],
          products: [
              \(wasmProductDeclarations)
          ],
          dependencies: [\(dependencyDeclarations)],
          targets: [
      \(wasmTargets)
          ],
          swiftLanguageModes: [.v6]
      )
      """
  }

  private func standardWasmRuntimeTargetDeclaration(
    targetName: String,
    appProductName: String
  ) -> String {
    """
    let \(Self.variableName(for: targetName)) = Target.executableTarget(
        name: "\(targetName)",
        dependencies: [
            "\(appProductName)",
            "SwiftWebActors",
            "SwiftHTML",
            "SwiftWebUI",
            "SwiftWebUIRuntime",
        ],
        path: "Sources/\(targetName)",
        swiftSettings: wasmSwiftSettings,
        linkerSettings: wasmLinkerSettings
    )
    """
  }

  private func embeddedWasmRuntimeTargetDeclaration(targetName: String) -> String {
    """
    let \(Self.variableName(for: targetName)) = Target.executableTarget(
        name: "\(targetName)",
        dependencies: [
            "SwiftHTMLClientRuntime",
            "JavaScriptKit",
        ],
        path: "Sources/\(targetName)",
        swiftSettings: wasmSwiftSettings,
        linkerSettings: wasmLinkerSettings
    )
    """
  }

  private func javaScriptKitTargetDeclarations() -> String {
    """
    let cJavaScriptKitTarget = Target.target(
        name: "_CJavaScriptKit",
        path: "Sources/_CJavaScriptKit"
    )

    let javaScriptKitTarget = Target.target(
        name: "JavaScriptKit",
        dependencies: [
            "_CJavaScriptKit",
        ],
        path: "Sources/JavaScriptKit",
        swiftSettings: [
            .enableExperimentalFeature("Extern"),
        ]
    )
    """
  }

  private static func productName(forWasmRuntimeTarget targetName: String) -> String {
    kebabCase(targetName)
  }

  private static func assetPath(forWasmRuntimeTarget targetName: String) -> String {
    "/assets/\(productName(forWasmRuntimeTarget: targetName)).wasm"
  }

  private static func wasmRuntimeTargetName(forClientComponent componentTypeName: String) -> String
  {
    if componentTypeName.hasPrefix("Client") {
      let suffix = componentTypeName.dropFirst("Client".count)
      if !suffix.isEmpty {
        return "\(suffix)WasmRuntime"
      }
    }
    if componentTypeName.hasSuffix("Component") {
      return "\(componentTypeName.dropLast("Component".count))WasmRuntime"
    }
    return "\(componentTypeName)WasmRuntime"
  }

  private static func wasmRuntimeTargetName(forBundleID bundleID: ClientBundleID) -> String {
    let parts = bundleID.rawValue
      .split(separator: "-")
      .map { part in
        part.prefix(1).uppercased() + part.dropFirst()
      }
      .joined()
    return "\(parts)WasmRuntime"
  }

  private static var coalescedPolicyOrder: [LoadPolicy] {
    [.visible, .interaction, .idle, .manual]
  }

  private static func wasmRuntimeTargetSuffix(for loadPolicy: LoadPolicy) -> String {
    switch loadPolicy {
    case .eager:
      return ""
    case .visible:
      return "Visible"
    case .interaction:
      return "Interaction"
    case .idle:
      return "Idle"
    case .manual:
      return "Manual"
    }
  }

  private static func variableName(for targetName: String) -> String {
    let first = targetName.prefix(1).lowercased()
    let rest = targetName.dropFirst()
    return "\(first)\(rest)Target"
  }

  private static func kebabCase(_ value: String) -> String {
    var output = ""
    for scalar in value.unicodeScalars {
      let character = Character(scalar)
      if CharacterSet.uppercaseLetters.contains(scalar) {
        if !output.isEmpty {
          output.append("-")
        }
        output.append(String(character).lowercased())
      } else {
        output.append(String(character))
      }
    }
    return output
  }

  private static func stableBundleName(_ value: String) -> String {
    let allowed = value.unicodeScalars.map { scalar -> Character in
      if CharacterSet.alphanumerics.contains(scalar)
        || scalar.value == 45
        || scalar.value == 95
      {
        return Character(scalar)
      }
      return "-"
    }
    let rawName = String(allowed)
      .split(separator: "-")
      .joined(separator: "-")
      .lowercased()
    guard !rawName.isEmpty else {
      return stableHashHex(value)
    }
    return rawName
  }

  private static func stableHashHex(_ value: String) -> String {
    var hash: UInt64 = 14_695_981_039_346_656_037
    for byte in value.utf8 {
      hash ^= UInt64(byte)
      hash &*= 1_099_511_628_211
    }
    return String(hash, radix: 16)
  }

  private static func localPackageIdentity(for packageDirectory: URL) -> String {
    packageDirectory
      .lastPathComponent
      .lowercased()
  }

  private static func swiftStringLiteral(_ value: String) -> String {
    value
      .replacingOccurrences(of: "\\", with: "\\\\")
      .replacingOccurrences(of: "\"", with: "\\\"")
      .replacingOccurrences(of: "\n", with: "\\n")
      .replacingOccurrences(of: "\r", with: "\\r")
  }

  private static func relativePath(from baseDirectory: URL, to targetDirectory: URL) -> String {
    let baseComponents = baseDirectory.standardizedFileURL.pathComponents
    let targetComponents = targetDirectory.standardizedFileURL.pathComponents
    var commonCount = 0

    while commonCount < baseComponents.count,
      commonCount < targetComponents.count,
      baseComponents[commonCount] == targetComponents[commonCount]
    {
      commonCount += 1
    }

    let parents = Array(repeating: "..", count: baseComponents.count - commonCount)
    let children = Array(targetComponents.dropFirst(commonCount))
    let components = parents + children
    return components.isEmpty ? "." : components.joined(separator: "/")
  }

  private static func uniqueTypeNames(_ typeNames: [String]) -> [String] {
    var seen = Set<String>()
    var unique: [String] = []
    for typeName in typeNames where seen.insert(typeName).inserted {
      unique.append(typeName)
    }
    return unique
  }

  private static func actorContracts(
    for components: [ClientComponentDeclaration]
  ) -> [ClientActorContractDeclaration] {
    var seen = Set<String>()
    var unique: [ClientActorContractDeclaration] = []
    for declaration in components
      .flatMap(\.actorContracts)
      .sorted(by: { $0.serviceTypeName < $1.serviceTypeName })
    where seen.insert(declaration.serviceTypeName).inserted {
      unique.append(declaration)
    }
    return unique
  }

  private func wasmEntrypointSwift(
    appProductName: String,
    target: WasmRuntimeTargetDeclaration
  ) -> String {
    switch wasmRuntimeProfile {
    case .standard:
      return standardWasmEntrypointSwift(appProductName: appProductName, target: target)
    case .embedded:
      return embeddedWasmEntrypointSwift(target: target)
    }
  }

  private func standardWasmEntrypointSwift(
    appProductName: String,
    target: WasmRuntimeTargetDeclaration
  ) -> String {
    let runtimeVariableName = "\(Self.lowerCamelCase(target.targetName))Runtime"
    let actorResolverVariableName = "\(Self.lowerCamelCase(target.targetName))ActorResolvers"
    let actorResolvers = target.actorContracts.map { contract in
      """
          SwiftWebActorResolver(
              contract: \(contract.contractKeyExpression),
              actorContract: \(contract.stubTypeName).self
          )
      """
    }
    .joined(separator: ",\n")
    let registrations = target.componentTypeNames.map { typeName in
      """
          ClientComponentRegistration(
              \(typeName).self,
              environmentRegistry: .swiftWebUI,
              actorResolverRegistry: \(actorResolverVariableName)
          ) { request in
              try makeSwiftWebWasmRoot(
                  \(typeName).self,
                  bootstrap: request,
                  fallback: \(typeName)()
              )
          }
      """
    }
    .joined(separator: ",\n")
    return """
      import \(appProductName)
      import SwiftHTML
      import SwiftWebActors
      import SwiftWebUI
      import SwiftWebUIRuntime

      private func makeSwiftWebWasmRoot<Root: HTML>(
          _ type: Root.Type,
          bootstrap request: ClientRuntimeBootstrapRequest,
          fallback: @autoclosure () -> Root
      ) throws -> Root {
          guard let bootstrapType = type as? any ClientRuntimeBootstrapInitializable.Type else {
              return fallback()
          }
          let root = try bootstrapType.init(bootstrap: request)
          guard let typedRoot = root as? Root else {
              throw ClientRuntimeBridgeError.componentMountNotFound(String(reflecting: type))
          }
          return typedRoot
      }

      nonisolated(unsafe) private let \(actorResolverVariableName) = SwiftWebActorResolverRegistry([
      \(actorResolvers)
      ])

      nonisolated(unsafe) private let \(runtimeVariableName) = ClientBundleRuntimeEntrypoint(
          registrations: [
      \(registrations)
          ]
      )

      @_cdecl("swiftweb_alloc")
      public func swiftweb_alloc(_ byteCount: UInt32) -> UInt32 {
          \(runtimeVariableName).allocate(byteCount: byteCount)
      }

      @_cdecl("swiftweb_dealloc")
      public func swiftweb_dealloc(_ pointer: UInt32, _ byteCount: UInt32) {
          \(runtimeVariableName).deallocate(pointer: pointer, byteCount: byteCount)
      }

      @_cdecl("swiftweb_bootstrap")
      public func swiftweb_bootstrap(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).bootstrap(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_dispatch_event")
      public func swiftweb_dispatch_event(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).dispatchEvent(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_snapshot_state")
      public func swiftweb_snapshot_state() -> UInt32 {
          \(runtimeVariableName).snapshotState()
      }

      @_cdecl("swiftweb_restore_state")
      public func swiftweb_restore_state(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).restoreState(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_response_ptr")
      public func swiftweb_response_ptr() -> UInt32 {
          \(runtimeVariableName).responsePointer()
      }

      @_cdecl("swiftweb_response_len")
      public func swiftweb_response_len() -> UInt32 {
          \(runtimeVariableName).responseLength()
      }

      @_cdecl("swiftweb_response_free")
      public func swiftweb_response_free() {
          \(runtimeVariableName).freeResponse()
      }

      @main
      struct \(target.targetName)Main {
          static func main() {}
      }
      """
  }

  private func embeddedWasmEntrypointSwift(target: WasmRuntimeTargetDeclaration) -> String {
    let runtimeVariableName = "\(Self.lowerCamelCase(target.targetName))Runtime"
    return """
      import JavaScriptKit
      import SwiftHTMLClientRuntime

      nonisolated(unsafe) private let \(runtimeVariableName) = SwiftWebClientRuntime()

      @_cdecl("swiftweb_alloc")
      public func swiftweb_alloc(_ byteCount: UInt32) -> UInt32 {
          \(runtimeVariableName).allocate(byteCount: byteCount)
      }

      @_cdecl("swiftweb_dealloc")
      public func swiftweb_dealloc(_ pointer: UInt32, _ byteCount: UInt32) {
          \(runtimeVariableName).deallocate(pointer: pointer, byteCount: byteCount)
      }

      @_cdecl("swiftweb_bootstrap")
      public func swiftweb_bootstrap(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).bootstrap(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_dispatch_event")
      public func swiftweb_dispatch_event(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).dispatchEvent(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_snapshot_state")
      public func swiftweb_snapshot_state() -> UInt32 {
          \(runtimeVariableName).snapshotState()
      }

      @_cdecl("swiftweb_restore_state")
      public func swiftweb_restore_state(_ pointer: UInt32, _ length: UInt32) -> UInt32 {
          \(runtimeVariableName).restoreState(pointer: pointer, length: length)
      }

      @_cdecl("swiftweb_response_ptr")
      public func swiftweb_response_ptr() -> UInt32 {
          \(runtimeVariableName).responsePointer()
      }

      @_cdecl("swiftweb_response_len")
      public func swiftweb_response_len() -> UInt32 {
          \(runtimeVariableName).responseLength()
      }

      @_cdecl("swiftweb_response_free")
      public func swiftweb_response_free() {
          \(runtimeVariableName).freeResponse()
      }

      @main
      struct \(target.targetName)Main {
          static func main() {}
      }

      final class SwiftWebClientRuntime {
          private var bootstrapped = false

          func allocate(byteCount: UInt32) -> UInt32 {
              let pointer = UnsafeMutableRawPointer.allocate(
                  byteCount: Int(byteCount),
                  alignment: MemoryLayout<UInt8>.alignment
              )
              return UInt32(UInt(bitPattern: pointer))
          }

          func deallocate(pointer: UInt32, byteCount: UInt32) {
              guard let rawPointer = UnsafeMutableRawPointer(bitPattern: Int(pointer)) else {
                  return
              }
              rawPointer.deallocate()
          }

          func bootstrap(pointer: UInt32, length: UInt32) -> UInt32 {
              if !bootstrapped {
                  installRuntimeMarker()
                  bootstrapped = true
              }
              return 0
          }

          func dispatchEvent(pointer: UInt32, length: UInt32) -> UInt32 {
              0
          }

          func snapshotState() -> UInt32 {
              0
          }

          func restoreState(pointer: UInt32, length: UInt32) -> UInt32 {
              0
          }

          func responsePointer() -> UInt32 {
              0
          }

          func responseLength() -> UInt32 {
              0
          }

          func freeResponse() {
          }

          private func installRuntimeMarker() {
              #if os(WASI)
              let document = JSObject.global.document.object!
              let root = document.documentElement.object!
              _ = root.setAttribute!("data-swiftweb-runtime", "embedded")

              let tree = ClientHTMLDocument {}
              tree.mount(
                  into: SwiftWebClientDOMHost(document: document),
                  parent: root
              )
              #endif
          }
      }

      struct SwiftWebClientDOMHost: ClientDOMHost {
          let document: JSObject

          func createElement(_ tagName: String) -> JSObject {
              document.createElement!(tagName).object!
          }

          func createText(_ text: String) -> JSObject {
              document.createTextNode!(text).object!
          }

          func setAttribute(_ attribute: ClientHTMLAttribute, on node: JSObject) {
              _ = node.setAttribute!(attribute.name, attribute.value)
          }

          func appendChild(_ child: JSObject, to parent: JSObject) {
              _ = parent.appendChild!(child)
          }
      }
      """
  }

  private static func lowerCamelCase(_ value: String) -> String {
    guard let first = value.first else {
      return value
    }
    return first.lowercased() + String(value.dropFirst())
  }
}

private extension SwiftWebWasmRuntimeProfile {
  func wasmSourceTargets(appProductName: String) -> [String] {
    switch self {
    case .standard:
      [
        appProductName,
        "_CJavaScriptKit",
        "JavaScriptKit",
        "SwiftHTML",
        "SwiftWebActors",
        "SwiftWebStyle",
        "SwiftWebUI",
        "SwiftWebUIRuntime",
      ]
    case .embedded:
      [
        "_CJavaScriptKit",
        "JavaScriptKit",
        "SwiftHTMLClientRuntime",
      ]
    }
  }
}

private struct WasmRuntimeTargetDeclaration: Sendable {
  let targetName: String
  let bundleID: ClientBundleID
  let componentTypeNames: [String]
  var actorContracts: [ClientActorContractDeclaration] = []
  var bundleArtifacts: [WasmRuntimeBundleArtifactDeclaration] = []
  let linkMode: SwiftWebGeneratedWasmRuntimeLinkMode

  var componentTypeName: String {
    componentTypeNames.first ?? targetName
  }
}

private struct WasmRuntimeBundleArtifactDeclaration: Sendable {
  let bundleID: ClientBundleID
  let componentTypeNames: [String]
}

private struct PackageResolvedFile: Decodable {
  let pins: [PackageResolvedPin]
}

private struct PackageResolvedPin: Decodable {
  let identity: String
  let location: String?
  let state: PackageResolvedPinState
}

private struct PackageResolvedPinState: Decodable {
  let version: String?
  let revision: String?
}
