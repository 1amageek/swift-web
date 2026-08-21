import ActorSystemGeneration
import Foundation

package struct SwiftWebEvaluatedPackageTargetGraph: Sendable {
  package struct Target: Sendable {
    package let moduleName: String
    package let packageRoot: URL
    package let sourceDirectory: URL
    package let sourceFiles: [URL]
    package let directDependencyModuleNames: Set<String>
    package let customConditions: Set<String>
    package let upcomingFeatures: Set<String>
    package let experimentalFeatures: Set<String>
    private let dependencyResolutionIssues: [String]
    private let projectionValidationIssues: [String]

    package var features: Set<String> {
      upcomingFeatures.union(experimentalFeatures)
    }

    package init(
      moduleName: String,
      packageRoot: URL,
      sourceDirectory: URL? = nil,
      sourceFiles: [URL] = [],
      directDependencyModuleNames: Set<String>,
      customConditions: Set<String> = [],
      upcomingFeatures: Set<String> = [],
      experimentalFeatures: Set<String> = [],
      dependencyResolutionIssues: [String] = [],
      projectionValidationIssues: [String] = []
    ) {
      self.moduleName = moduleName
      self.packageRoot = packageRoot.standardizedFileURL
      self.sourceDirectory = (sourceDirectory ?? packageRoot
        .appendingPathComponent("Sources", isDirectory: true)
        .appendingPathComponent(moduleName, isDirectory: true))
        .standardizedFileURL
      self.sourceFiles = sourceFiles.map(\.standardizedFileURL).sorted {
        $0.path < $1.path
      }
      self.directDependencyModuleNames = directDependencyModuleNames
      self.customConditions = customConditions
      self.upcomingFeatures = upcomingFeatures
      self.experimentalFeatures = experimentalFeatures
      self.dependencyResolutionIssues = dependencyResolutionIssues
      self.projectionValidationIssues = projectionValidationIssues
    }

    package func validateDependencyResolution() throws {
      guard dependencyResolutionIssues.isEmpty else {
        throw ActorGenerationError.schemaConflict(
          reason: dependencyResolutionIssues.joined(separator: "; ")
        )
      }
    }

    package func validateGeneratedProjectionCapabilities() throws {
      guard projectionValidationIssues.isEmpty else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: projectionValidationIssues.joined(separator: "; ")
        )
      }
    }
  }

  private let targetsByModule: [String: Target]

  fileprivate init(targetsByModule: [String: Target]) {
    self.targetsByModule = targetsByModule
  }

  package init(targets: [Target]) throws {
    var indexed: [String: Target] = [:]
    for target in targets {
      guard indexed.updateValue(target, forKey: target.moduleName) == nil else {
        throw ActorGenerationError.schemaConflict(
          reason: "SwiftPM target graph contains duplicate module \(target.moduleName)"
        )
      }
    }
    targetsByModule = indexed
  }

  package func target(named moduleName: String) -> Target? {
    targetsByModule[moduleName]
  }

  package var targets: [Target] {
    targetsByModule.values.sorted { $0.moduleName < $1.moduleName }
  }

  package func directDependencyModuleNames(
    of moduleName: String
  ) throws -> Set<String> {
    guard let target = targetsByModule[moduleName] else {
      throw ActorGenerationError.schemaConflict(
        reason: "SwiftPM target graph has no target named \(moduleName)"
      )
    }
    try target.validateDependencyResolution()
    return target.directDependencyModuleNames
  }

  package func reachableModuleNames(
    from rootModuleName: String
  ) throws -> Set<String> {
    var pending = [rootModuleName]
    var visited = Set<String>()
    while let moduleName = pending.popLast() {
      guard visited.insert(moduleName).inserted else {
        continue
      }
      guard let target = targetsByModule[moduleName] else {
        throw ActorGenerationError.schemaConflict(
          reason: "SwiftPM target graph edge references missing target \(moduleName)"
        )
      }
      try target.validateDependencyResolution()
      pending.append(contentsOf: target.directDependencyModuleNames)
    }
    return visited
  }
}

package enum SwiftWebEvaluatedPackageTargetGraphLoader {
  package struct ManifestDump: Sendable {
    package let identity: String
    package let packageRoot: URL
    package let data: Data
    package let describedPackageData: Data?
    package let isRoot: Bool

    package init(
      identity: String,
      packageRoot: URL,
      data: Data,
      describedPackageData: Data? = nil,
      isRoot: Bool = false
    ) {
      self.identity = identity
      self.packageRoot = packageRoot.standardizedFileURL
      self.data = data
      self.describedPackageData = describedPackageData
      self.isRoot = isRoot
    }
  }

  package static func load(
    packageDirectory: URL,
    swiftExecutable: URL,
    environment: [String: String],
    targetEnvironment: ActorGenerationTargetEnvironment
  ) throws -> SwiftWebEvaluatedPackageTargetGraph {
    let dependencyData = try runSwiftPackageCommand(
      ["package", "show-dependencies", "--format", "json"],
      in: packageDirectory,
      swiftExecutable: swiftExecutable,
      environment: environment
    )
    let dependencyRoot: PackageDependencyNode
    do {
      dependencyRoot = try JSONDecoder().decode(
        PackageDependencyNode.self,
        from: dependencyData
      )
    } catch {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package show-dependencies returned invalid JSON: \(error)"
      )
    }
    let packageNodes = dependencyRoot.flattened()
    let normalizedRootPath = packageDirectory.standardizedFileURL.path
    var dumpedPackages: [DumpedPackage] = []
    for packageNode in packageNodes.sorted(by: { $0.path < $1.path }) {
      let root = URL(fileURLWithPath: packageNode.path, isDirectory: true)
        .standardizedFileURL
      let manifestData = try runSwiftPackageCommand(
        ["package", "dump-package"],
        in: root,
        swiftExecutable: swiftExecutable,
        environment: environment
      )
      let describedPackageData = try runSwiftPackageCommand(
        ["package", "describe", "--type", "json"],
        in: root,
        swiftExecutable: swiftExecutable,
        environment: environment
      )
      dumpedPackages.append(
        try DumpedPackage(
          data: manifestData,
          describedPackageData: describedPackageData,
          identity: packageNode.identity,
          packageRoot: root
        )
      )
    }
    return try decode(
      manifestDumps: dumpedPackages.map {
        ManifestDump(
          identity: $0.identity,
          packageRoot: $0.packageRoot,
          data: $0.data,
          describedPackageData: $0.describedPackageData,
          isRoot: $0.packageRoot.standardizedFileURL.path == normalizedRootPath
        )
      },
      targetEnvironment: targetEnvironment
    )
  }

  package static func decode(
    manifestDumps: [ManifestDump],
    targetEnvironment: ActorGenerationTargetEnvironment
  ) throws -> SwiftWebEvaluatedPackageTargetGraph {
    let dumpedPackages = try manifestDumps.map {
      guard let describedPackageData = $0.describedPackageData else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "Evaluated SwiftPM graph is missing package describe output for \($0.packageRoot.path)"
        )
      }
      return try DumpedPackage(
        data: $0.data,
        describedPackageData: describedPackageData,
        identity: $0.identity,
        packageRoot: $0.packageRoot
      )
    }
    let explicitlyMarkedRoots = manifestDumps.filter(\.isRoot)
    guard explicitlyMarkedRoots.count <= 1 else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "Evaluated SwiftPM graph contains more than one root package"
      )
    }
    guard let rootIdentity = explicitlyMarkedRoots.first?.identity
      ?? manifestDumps.first?.identity
    else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "Evaluated SwiftPM graph contains no package manifests"
      )
    }
    var dumpedPackagesByIdentity: [String: DumpedPackage] = [:]
    for package in dumpedPackages {
      let identity = normalizedPackageIdentity(package.identity)
      guard dumpedPackagesByIdentity.updateValue(package, forKey: identity) == nil else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "Evaluated SwiftPM graph contains duplicate package identity \(identity)"
        )
      }
    }
    guard let rootPackage = dumpedPackagesByIdentity[
      normalizedPackageIdentity(rootIdentity)
    ] else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "Evaluated SwiftPM graph cannot identify its root package"
      )
    }
    var activeTraitsByIdentity: [String: Set<String>] = [
      normalizedPackageIdentity(rootIdentity): rootPackage.defaultTraits,
    ]
    var changed = true
    while changed {
      changed = false
      for package in dumpedPackages {
        for request in package.dependencyTraitRequests {
          let identity = normalizedPackageIdentity(request.identity)
          let hadPreviousRequest = activeTraitsByIdentity[identity] != nil
          let previous = activeTraitsByIdentity[identity] ?? []
          let defaultTraits = request.usesDefaultTraits
            ? dumpedPackagesByIdentity[identity]?.defaultTraits ?? []
            : []
          let requested = previous.union(defaultTraits).union(request.traits)
          let next = dumpedPackagesByIdentity[identity]
            .map { $0.expandedTraits(requested) }
            ?? requested
          if !hadPreviousRequest || next != previous {
            activeTraitsByIdentity[identity] = next
            changed = changed || next != previous
          }
        }
      }
    }
    let manifests = try dumpedPackages.map { package in
      try EvaluatedPackageManifest(
        data: package.data,
        identity: package.identity,
        packageRoot: package.packageRoot,
        describedPackageData: package.describedPackageData,
        platformName: swiftPMPlatformName(targetEnvironment.operatingSystem),
        activeTraits: activeTraitsByIdentity[
          normalizedPackageIdentity(package.identity)
        ] ?? []
      )
    }
    return try makeGraph(manifests: manifests)
  }

  private static func makeGraph(
    manifests: [EvaluatedPackageManifest]
  ) throws -> SwiftWebEvaluatedPackageTargetGraph {
    var targetOwners: [String: EvaluatedPackageManifest] = [:]
    for manifest in manifests {
      for moduleName in manifest.targets.keys {
        if let existing = targetOwners[moduleName],
           existing.packageRoot != manifest.packageRoot {
          throw ActorGenerationError.schemaConflict(
            reason: "SwiftPM target \(moduleName) is declared by both \(existing.packageRoot.path) and \(manifest.packageRoot.path)"
          )
        }
        targetOwners[moduleName] = manifest
      }
    }

    var productsByName: [String: [(manifest: EvaluatedPackageManifest, product: EvaluatedProduct)]] = [:]
    for manifest in manifests {
      for product in manifest.products.values {
        productsByName[product.name, default: []].append((manifest, product))
      }
    }

    var targets: [String: SwiftWebEvaluatedPackageTargetGraph.Target] = [:]
    for manifest in manifests {
      for target in manifest.targets.values {
        var dependencies = Set<String>()
        var dependencyResolutionIssues: [String] = []
        for dependency in target.dependencies {
          do {
            switch dependency {
            case .target(let name):
              guard manifest.targets[name] != nil else {
                throw ActorGenerationError.schemaConflict(
                  reason: "SwiftPM target \(target.name) references missing target \(name) in \(manifest.packageRoot.path)"
                )
              }
              dependencies.insert(name)
            case .byName(let name):
              if manifest.targets[name] != nil {
                dependencies.insert(name)
              } else {
                dependencies.formUnion(
                  try resolveProductTargets(
                    name: name,
                    packageReference: nil,
                    requestingManifest: manifest,
                    productsByName: productsByName
                  )
                )
              }
            case .product(let name, let packageReference):
              dependencies.formUnion(
                try resolveProductTargets(
                  name: name,
                  packageReference: packageReference,
                  requestingManifest: manifest,
                  productsByName: productsByName
                )
              )
            }
          } catch let error as ActorGenerationError {
            dependencyResolutionIssues.append(String(describing: error))
          }
        }
        targets[target.name] = SwiftWebEvaluatedPackageTargetGraph.Target(
          moduleName: target.name,
          packageRoot: manifest.packageRoot,
          sourceDirectory: target.sourceDirectory,
          sourceFiles: target.sourceFiles,
          directDependencyModuleNames: dependencies,
          customConditions: target.customConditions,
          upcomingFeatures: target.upcomingFeatures,
          experimentalFeatures: target.experimentalFeatures,
          dependencyResolutionIssues: dependencyResolutionIssues,
          projectionValidationIssues: target.projectionValidationIssues
        )
      }
    }
    return SwiftWebEvaluatedPackageTargetGraph(targetsByModule: targets)
  }

  private static func resolveProductTargets(
    name: String,
    packageReference: String?,
    requestingManifest: EvaluatedPackageManifest,
    productsByName: [String: [(manifest: EvaluatedPackageManifest, product: EvaluatedProduct)]]
  ) throws -> Set<String> {
    let candidates = (productsByName[name] ?? []).filter { candidate in
      guard let packageReference, !packageReference.isEmpty else {
        return candidate.manifest.packageRoot == requestingManifest.packageRoot
          || productsByName[name]?.count == 1
      }
      let normalizedReference = normalizedPackageIdentity(packageReference)
      return normalizedPackageIdentity(candidate.manifest.identity) == normalizedReference
        || normalizedPackageIdentity(candidate.manifest.name) == normalizedReference
        || normalizedPackageIdentity(candidate.manifest.packageRoot.lastPathComponent)
          == normalizedReference
    }
    guard candidates.count == 1, let candidate = candidates.first else {
      let locations = candidates.map { $0.manifest.packageRoot.path }.sorted()
      throw ActorGenerationError.schemaConflict(
        reason: "SwiftPM product dependency \(name) from \(requestingManifest.packageRoot.path) is \(candidates.isEmpty ? "missing" : "ambiguous at \(locations.joined(separator: ", "))")"
      )
    }
    return Set(candidate.product.targetNames)
  }

  private static func runSwiftPackageCommand(
    _ arguments: [String],
    in packageDirectory: URL,
    swiftExecutable: URL,
    environment: [String: String]
  ) throws -> Data {
    let outputDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(
      "swiftweb-package-graph-\(UUID().uuidString)",
      isDirectory: true
    )
    try FileManager.default.createDirectory(
      at: outputDirectory,
      withIntermediateDirectories: true
    )
    defer {
      do {
        try FileManager.default.removeItem(at: outputDirectory)
      } catch {
        // Temporary output cleanup does not change SwiftPM graph evaluation.
      }
    }
    let standardOutputURL = outputDirectory.appendingPathComponent("stdout.json")
    let standardErrorURL = outputDirectory.appendingPathComponent("stderr.txt")
    guard FileManager.default.createFile(atPath: standardOutputURL.path, contents: nil),
          FileManager.default.createFile(atPath: standardErrorURL.path, contents: nil) else {
      throw ActorGenerationError.sourceWriteFailure(
        path: outputDirectory.path,
        reason: "Cannot create SwiftPM graph command output files"
      )
    }
    let standardOutput = try FileHandle(forWritingTo: standardOutputURL)
    let standardError = try FileHandle(forWritingTo: standardErrorURL)
    defer {
      do {
        try standardOutput.close()
      } catch {
        // The process status and captured bytes are the authoritative result.
      }
      do {
        try standardError.close()
      } catch {
        // The process status and captured bytes are the authoritative result.
      }
    }
    let process = Process()
    process.executableURL = swiftExecutable
    process.arguments = arguments
    process.currentDirectoryURL = packageDirectory
    process.environment = environment
    process.standardOutput = standardOutput
    process.standardError = standardError
    try process.run()
    process.waitUntilExit()
    try standardOutput.synchronize()
    try standardError.synchronize()
    let outputData = try Data(contentsOf: standardOutputURL)
    let errorData = try Data(contentsOf: standardErrorURL)
    guard process.terminationStatus == 0 else {
      throw ActorGenerationError.toolchainFailure(
        command: ([swiftExecutable.path] + arguments).joined(separator: " "),
        status: process.terminationStatus,
        output: [outputData, errorData]
          .map { String(decoding: $0, as: UTF8.self) }
          .filter { !$0.isEmpty }
          .joined(separator: "\n")
      )
    }
    return outputData
  }

  private static func swiftPMPlatformName(_ operatingSystem: String) -> String {
    switch operatingSystem {
    case "macOS": "macos"
    case "iOS": "ios"
    case "tvOS": "tvos"
    case "watchOS": "watchos"
    case "visionOS": "visionos"
    case "WASI": "wasi"
    default: operatingSystem.lowercased()
    }
  }

  private static func normalizedPackageIdentity(_ value: String) -> String {
    value.lowercased()
      .replacingOccurrences(of: "_", with: "-")
      .replacingOccurrences(of: ".git", with: "")
  }
}

private struct PackageDependencyNode: Decodable {
  let identity: String
  let name: String
  let path: String
  let dependencies: [PackageDependencyNode]

  func flattened() -> [PackageDependencyNode] {
    var result: [PackageDependencyNode] = []
    var pending = [self]
    var visited = Set<String>()
    while let node = pending.popLast() {
      let standardizedPath = URL(fileURLWithPath: node.path).standardizedFileURL.path
      guard visited.insert(standardizedPath).inserted else {
        continue
      }
      result.append(node)
      pending.append(contentsOf: node.dependencies)
    }
    return result
  }
}

private struct EvaluatedProduct {
  let name: String
  let targetNames: [String]
}

private struct DumpedPackage {
  struct TraitRequest {
    let identity: String
    let traits: Set<String>
    let usesDefaultTraits: Bool
  }

  let data: Data
  let describedPackageData: Data
  let identity: String
  let packageRoot: URL
  let defaultTraits: Set<String>
  let enabledTraitsByName: [String: Set<String>]
  let dependencyTraitRequests: [TraitRequest]

  init(
    data: Data,
    describedPackageData: Data,
    identity: String,
    packageRoot: URL
  ) throws {
    let object = try JSONSerialization.jsonObject(with: data)
    guard let root = object as? [String: Any] else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package dump-package returned a non-object for \(packageRoot.path)"
      )
    }
    self.data = data
    self.describedPackageData = describedPackageData
    self.identity = identity
    self.packageRoot = packageRoot
    enabledTraitsByName = Self.enabledTraits(root["traits"])
    defaultTraits = Self.expand(
      enabledTraitsByName["default"] ?? [],
      enabledTraitsByName: enabledTraitsByName
    )
    dependencyTraitRequests = (root["dependencies"] as? [Any] ?? []).compactMap {
      Self.traitRequest(from: $0)
    }
  }

  func expandedTraits(_ traits: Set<String>) -> Set<String> {
    Self.expand(traits, enabledTraitsByName: enabledTraitsByName)
  }

  private static func enabledTraits(_ value: Any?) -> [String: Set<String>] {
    guard let traits = value as? [[String: Any]] else {
      return [:]
    }
    return Dictionary(uniqueKeysWithValues: traits.compactMap { trait in
      guard let name = trait["name"] as? String else {
        return nil
      }
      return (name, Set(trait["enabledTraits"] as? [String] ?? []))
    })
  }

  private static func expand(
    _ traits: Set<String>,
    enabledTraitsByName: [String: Set<String>]
  ) -> Set<String> {
    var pending = Array(traits)
    var active = Set<String>()
    while let name = pending.popLast() {
      guard active.insert(name).inserted else {
        continue
      }
      pending.append(contentsOf: enabledTraitsByName[name] ?? [])
    }
    return active
  }

  private static func traitRequest(from value: Any) -> TraitRequest? {
    guard let dictionary = value as? [String: Any] else {
      return nil
    }
    if let identity = dictionary["identity"] as? String {
      let traitValue = dictionary["traits"]
      return TraitRequest(
        identity: identity,
        traits: traitNames(in: traitValue),
        usesDefaultTraits: traitValue == nil || traitValue is NSNull
      )
    }
    for key in dictionary.keys.sorted() {
      if let values = dictionary[key] as? [Any] {
        for value in values {
          if let request = traitRequest(from: value) {
            return request
          }
        }
      } else if let request = traitRequest(from: dictionary[key] as Any) {
        return request
      }
    }
    return nil
  }

  private static func traitNames(in value: Any?) -> Set<String> {
    guard let values = value as? [Any] else {
      return []
    }
    return Set(values.compactMap { value in
      if let name = value as? String {
        return name
      }
      return (value as? [String: Any])?["name"] as? String
    })
  }
}

private enum EvaluatedTargetDependency {
  case target(String)
  case product(name: String, package: String?)
  case byName(String)
}

private struct EvaluatedTarget {
  let name: String
  let sourceDirectory: URL
  let sourceFiles: [URL]
  let dependencies: [EvaluatedTargetDependency]
  let customConditions: Set<String>
  let upcomingFeatures: Set<String>
  let experimentalFeatures: Set<String>
  let projectionValidationIssues: [String]
}

private struct EvaluatedPackageManifest {
  let identity: String
  let name: String
  let packageRoot: URL
  let products: [String: EvaluatedProduct]
  let targets: [String: EvaluatedTarget]

  init(
    data: Data,
    identity: String,
    packageRoot: URL,
    describedPackageData: Data,
    platformName: String,
    activeTraits: Set<String>
  ) throws {
    let object: Any
    do {
      object = try JSONSerialization.jsonObject(with: data)
    } catch {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package dump-package returned invalid JSON for \(packageRoot.path): \(error)"
      )
    }
    guard let root = object as? [String: Any],
      let packageName = root["name"] as? String
    else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package dump-package omitted the package name for \(packageRoot.path)"
      )
    }
    var parsedProducts: [String: EvaluatedProduct] = [:]
    for productValue in root["products"] as? [[String: Any]] ?? [] {
      guard let productName = productValue["name"] as? String,
        let targetNames = productValue["targets"] as? [String]
      else {
        continue
      }
      parsedProducts[productName] = EvaluatedProduct(
        name: productName,
        targetNames: targetNames
      )
    }
    let describedTargets = try Self.describedTargets(
      describedPackageData,
      packageRoot: packageRoot
    )
    var parsedTargets: [String: EvaluatedTarget] = [:]
    for targetValue in root["targets"] as? [[String: Any]] ?? [] {
      guard let targetName = targetValue["name"] as? String else {
        continue
      }
      guard let describedTarget = describedTargets[targetName] else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "swift package describe omitted target \(targetName) for \(packageRoot.path)"
        )
      }
      let dependencies = try (targetValue["dependencies"] as? [[String: Any]] ?? [])
        .compactMap { dependency in
          try Self.dependency(
            dependency,
            platformName: platformName,
            activeTraits: activeTraits
          )
        }
      let buildConditions = try Self.buildConditions(
        targetValue["settings"],
        targetName: targetName,
        platformName: platformName,
        activeTraits: activeTraits
      )
      parsedTargets[targetName] = EvaluatedTarget(
        name: targetName,
        sourceDirectory: describedTarget.sourceDirectory,
        sourceFiles: describedTarget.sourceFiles,
        dependencies: dependencies,
        customConditions: buildConditions.customConditions,
        upcomingFeatures: buildConditions.upcomingFeatures,
        experimentalFeatures: buildConditions.experimentalFeatures,
        projectionValidationIssues: buildConditions.projectionValidationIssues
      )
    }
    self.identity = identity
    name = packageName
    self.packageRoot = packageRoot
    products = parsedProducts
    targets = parsedTargets
  }

  private static func dependency(
    _ value: [String: Any],
    platformName: String,
    activeTraits: Set<String>
  ) throws -> EvaluatedTargetDependency? {
    let supportedKinds = ["target", "product", "byName"]
    let unknownKinds = value.keys.filter { key in
      guard !supportedKinds.contains(key), let value = value[key] else {
        return false
      }
      return !isNull(value)
    }.sorted()
    guard unknownKinds.isEmpty else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "SwiftPM target dependency contains unsupported fields: \(unknownKinds.joined(separator: ", "))"
      )
    }
    let presentKinds = supportedKinds.filter { kind in
      guard let value = value[kind] else {
        return false
      }
      return !isNull(value)
    }
    guard presentKinds.count == 1,
          let kind = presentKinds.first,
          let elements = value[kind] as? [Any],
          let name = elements.first as? String,
          !name.isEmpty else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package dump-package returned an unknown or malformed target dependency \(value)"
      )
    }

    let maximumElementCount = kind == "product" ? 4 : 2
    guard elements.count <= maximumElementCount else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "SwiftPM target dependency \(name) has an unsupported serialized shape"
      )
    }

    var packageReference: String?
    if kind == "product", elements.indices.contains(1), !isNull(elements[1]) {
      guard let package = elements[1] as? String, !package.isEmpty else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "SwiftPM product dependency \(name) contains a malformed package reference"
        )
      }
      packageReference = package
    }
    if kind == "product", elements.indices.contains(2), !isNull(elements[2]) {
      guard let moduleAliases = elements[2] as? [String: String],
            moduleAliases.isEmpty else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "SwiftPM product dependency \(name) uses module aliases that generated actor targets cannot reproduce"
        )
      }
    }

    let conditionValue: Any? = kind == "product"
      ? (elements.indices.contains(3) ? elements[3] : nil)
      : (elements.indices.contains(1) ? elements[1] : nil)
    if let conditionValue, !isNull(conditionValue) {
      guard let condition = conditionValue as? [String: Any] else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "SwiftPM target dependency \(name) contains a malformed condition"
        )
      }
      let isActive = try conditionIsActive(
        condition,
        platformName: platformName,
        activeTraits: activeTraits
      )
      if !isActive {
        return nil
      }
    }

    switch kind {
    case "target": return .target(name)
    case "byName": return .byName(name)
    default:
      return .product(name: name, package: packageReference)
    }
  }

  private static func conditionIsActive(
    _ condition: [String: Any],
    platformName: String,
    activeTraits: Set<String>
  ) throws -> Bool {
    let knownConditionKeys: Set<String> = [
      "platformNames", "traits", "configuration", "config",
    ]
    let unknownKeys = condition.keys.filter { key in
      guard !knownConditionKeys.contains(key), let value = condition[key] else {
        return false
      }
      return !isNull(value)
    }.sorted()
    guard unknownKeys.isEmpty else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "SwiftPM condition contains unsupported fields: \(unknownKeys.joined(separator: ", "))"
      )
    }
    for key in ["configuration", "config"] {
      guard let value = condition[key], !isNull(value) else {
        continue
      }
      let configuration = nestedString(value) ?? String(describing: value)
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "SwiftPM build configuration condition '\(configuration)' cannot be reproduced in one generated package shared by development and release builds"
      )
    }
    let platforms = try stringArrayCondition(
      condition["platformNames"],
      field: "platformNames"
    )
    let traits = try stringArrayCondition(condition["traits"], field: "traits")
    return (platforms.isEmpty || platforms.map { $0.lowercased() }.contains(platformName))
      && Set(traits).isSubset(of: activeTraits)
  }

  private static func buildConditions(
    _ value: Any?,
    targetName: String,
    platformName: String,
    activeTraits: Set<String>
  ) throws -> (
    customConditions: Set<String>,
    upcomingFeatures: Set<String>,
    experimentalFeatures: Set<String>,
    projectionValidationIssues: [String]
  ) {
    guard let value, !isNull(value) else {
      return ([], [], [], [])
    }
    guard let settings = value as? [[String: Any]] else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "SwiftPM target \(targetName) contains malformed build settings"
      )
    }
    var customConditions = Set<String>()
    var upcomingFeatures = Set<String>()
    var experimentalFeatures = Set<String>()
    var projectionValidationIssues: [String] = []
    for setting in settings {
      if let conditionValue = setting["condition"], !isNull(conditionValue) {
        guard let condition = conditionValue as? [String: Any] else {
          projectionValidationIssues.append(
            "SwiftPM target \(targetName) contains a build setting with a malformed condition"
          )
          continue
        }
        let isActive: Bool
        do {
          isActive = try conditionIsActive(
            condition,
            platformName: platformName,
            activeTraits: activeTraits
          )
        } catch {
          projectionValidationIssues.append(String(describing: error))
          continue
        }
        if !isActive {
          continue
        }
      }
      guard let kind = setting["kind"] as? [String: Any] else {
        projectionValidationIssues.append(
          "SwiftPM target \(targetName) contains a build setting without a kind"
        )
        continue
      }
      let supportedKinds: Set<String> = [
        "define", "enableUpcomingFeature", "enableExperimentalFeature",
      ]
      let unknownKinds = kind.keys.filter { !supportedKinds.contains($0) }.sorted()
      guard unknownKinds.isEmpty else {
        projectionValidationIssues.append(
          "SwiftPM target \(targetName) contains build settings that generated targets cannot reproduce: \(unknownKinds.joined(separator: ", "))"
        )
        continue
      }
      let presentKinds = supportedKinds.filter { key in
        guard let value = kind[key] else {
          return false
        }
        return !isNull(value)
      }
      guard presentKinds.count == 1,
            let settingKind = presentKinds.first,
            let settingValue = nestedString(kind[settingKind]),
            !settingValue.isEmpty else {
        projectionValidationIssues.append(
          "SwiftPM target \(targetName) contains a malformed or ambiguous build setting kind"
        )
        continue
      }
      if settingKind == "define" {
        let definition = settingValue
        customConditions.insert(definition)
      }
      if settingKind == "enableUpcomingFeature" {
        let feature = settingValue
        upcomingFeatures.insert(feature)
      }
      if settingKind == "enableExperimentalFeature" {
        let feature = settingValue
        experimentalFeatures.insert(feature)
      }
    }
    return (
      customConditions,
      upcomingFeatures,
      experimentalFeatures,
      projectionValidationIssues
    )
  }

  private static func stringArrayCondition(
    _ value: Any?,
    field: String
  ) throws -> [String] {
    guard let value, !isNull(value) else {
      return []
    }
    guard let values = value as? [String] else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "SwiftPM condition field \(field) has an unsupported value"
      )
    }
    return values
  }

  private static func describedTargets(
    _ data: Data,
    packageRoot: URL
  ) throws -> [String: DescribedTarget] {
    let object: Any
    do {
      object = try JSONSerialization.jsonObject(with: data)
    } catch {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package describe returned invalid JSON for \(packageRoot.path): \(error)"
      )
    }
    guard let root = object as? [String: Any],
          let targets = root["targets"] as? [[String: Any]] else {
      throw ActorGenerationError.invalidCompilerOutput(
        reason: "swift package describe omitted targets for \(packageRoot.path)"
      )
    }
    var result: [String: DescribedTarget] = [:]
    for target in targets {
      guard let name = target["name"] as? String,
            let targetPath = target["path"] as? String else {
        continue
      }
      let targetDirectory = resolvedPath(targetPath, relativeTo: packageRoot, isDirectory: true)
      let sources = (target["sources"] as? [String] ?? []).compactMap { source -> URL? in
        let url = resolvedPath(source, relativeTo: targetDirectory, isDirectory: false)
        guard url.pathExtension == "swift" else {
          return nil
        }
        return url
      }
      let describedTarget = DescribedTarget(
        sourceDirectory: targetDirectory,
        sourceFiles: sources.sorted { $0.path < $1.path }
      )
      guard result.updateValue(describedTarget, forKey: name) == nil else {
        throw ActorGenerationError.invalidCompilerOutput(
          reason: "swift package describe contains duplicate target \(name) for \(packageRoot.path)"
        )
      }
    }
    return result
  }

  private static func resolvedPath(
    _ path: String,
    relativeTo base: URL,
    isDirectory: Bool
  ) -> URL {
    if path.hasPrefix("/") {
      return URL(fileURLWithPath: path, isDirectory: isDirectory).standardizedFileURL
    }
    return base.appendingPathComponent(path, isDirectory: isDirectory).standardizedFileURL
  }

  private struct DescribedTarget {
    let sourceDirectory: URL
    let sourceFiles: [URL]
  }

  private static func nestedString(_ value: Any?) -> String? {
    if let value = value as? String {
      return value
    }
    if let values = value as? [Any] {
      return values.lazy.compactMap(nestedString).first
    }
    if let values = value as? [String: Any] {
      return values.keys.sorted().lazy.compactMap { nestedString(values[$0]) }.first
    }
    return nil
  }

  private static func isNull(_ value: Any) -> Bool {
    value is NSNull
  }
}
