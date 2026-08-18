import Foundation
import Synchronization
import SwiftHTML
import Testing

@testable import ActorSystemGeneration
@testable import ActorSystemBuildSupport
@testable import SwiftWebPackageGeneration
@testable import SwiftWebWasmBuild
import SwiftWebDevelopmentHooks

@Suite
struct SwiftWebGeneratedPackageMaterializerTests {
  @Test
  func importedModulesSelectsOnlyTheActiveProfileBranch() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "SwiftWebGeneratedPackageMaterializerImports-\(UUID().uuidString)",
      isDirectory: true
    )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("Failed to remove temporary directory: \(error)")
      }
    }
    try FileManager.default.createDirectory(
      at: root,
      withIntermediateDirectories: true
    )
    let sourceURL = root.appendingPathComponent("ConditionalImports.swift")
    try """
    import SwiftWeb
    #if os(WASI)
      #if hasFeature(Embedded)
      import EmbeddedActors
      #else
      import StandardActors
      #endif
    #else
    import HostActors
    #endif
    #if ROOT_ACTORS
    import RootActorExtension
    #endif
    """.write(to: sourceURL, atomically: true, encoding: .utf8)

    let rootConfiguredEnvironment = try wasmEnvironment(
      embedded: false,
      availableModules: [
        "EmbeddedActors", "StandardActors", "HostActors", "RootActorExtension", "SwiftWeb",
      ]
    ).addingBuildConditions(customConditions: ["ROOT_ACTORS"])
    let standardImports = try SwiftWebGeneratedPackageMaterializer.importedModules(
      in: [(url: sourceURL, relativePath: "ConditionalImports.swift")],
      targetEnvironment: rootConfiguredEnvironment
    )
    let embeddedImports = try SwiftWebGeneratedPackageMaterializer.importedModules(
      in: [(url: sourceURL, relativePath: "ConditionalImports.swift")],
      targetEnvironment: wasmEnvironment(
        embedded: true,
        availableModules: ["EmbeddedActors", "StandardActors", "HostActors", "SwiftWeb"]
      )
    )

    #expect(standardImports == Set(["RootActorExtension", "StandardActors", "SwiftWeb"]))
    #expect(embeddedImports == Set(["EmbeddedActors", "SwiftWeb"]))
  }

  @Test
  func dependencyProjectionMirrorsRetainedClientDeclarations() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "SwiftWebActorDependencyProjection-\(UUID().uuidString)",
      isDirectory: true
    )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("Failed to remove temporary directory: \(error)")
      }
    }
    let sourceDirectory = root.appendingPathComponent("Sources/SharedActors", isDirectory: true)
    let source = """
    #if canImport(Distributed)
    import Distributed
    #endif

    public struct ClientHelper {
      public init() {}
    }

    #if hasFeature(Embedded)
    public let dependencyClientMarker = "client"
    #else
    private let dependencyServerSecret = "secret"
    #endif

    distributed actor SharedCounter {
      typealias ActorSystem = TestActorSystem
      distributed func value() async throws -> Int { 1 }
    }
    """
    try write(source, to: sourceDirectory.appendingPathComponent("Feature.swift"))
    let serverOnlySource = "let dependencyServerSecret = \"secret\""
    try write(
      serverOnlySource,
      to: sourceDirectory.appendingPathComponent("Actions/Secret.swift")
    )
    try write(
      serverOnlySource,
      to: sourceDirectory.appendingPathComponent("App.swift")
    )
    let manifest = ActorGeneratedManifest(
      packageIdentity: "shared",
      moduleName: "SharedActors",
      profile: .embeddedClient,
      toolchainFingerprint: "fixture",
      sourceRoot: sourceDirectory.path,
      inputSources: [
        ActorGeneratedManifest.InputSource(
          relativePath: "Feature.swift",
          contentDigest: ActorStableHash.digest(source),
          replacedActorNames: ["SharedCounter"],
          replacedPortableTypeNames: []
        ),
        ActorGeneratedManifest.InputSource(
          relativePath: "Actions/Secret.swift",
          contentDigest: ActorStableHash.digest(serverOnlySource),
          replacedActorNames: [],
          replacedPortableTypeNames: []
        ),
        ActorGeneratedManifest.InputSource(
          relativePath: "App.swift",
          contentDigest: ActorStableHash.digest(serverOnlySource),
          replacedActorNames: [],
          replacedPortableTypeNames: []
        )
      ],
      generatedFiles: [],
      dependencySchemas: [],
      schemaContentDigest: "fixture",
      schemaModuleTypeName: "SharedActorsActorSchemaModule",
      bootstrapTypeName: "SharedActorsActorSystemBootstrap"
    )
    let generatedDirectory = root.appendingPathComponent("generated", isDirectory: true)
    try FileManager.default.createDirectory(
      at: generatedDirectory,
      withIntermediateDirectories: true
    )
    let projection = SwiftWebActorDependencyProjection(
      moduleName: "SharedActors",
      dependencyModuleNames: [],
      clientImportedModuleNames: [],
      customConditions: [],
      upcomingFeatures: [],
      experimentalFeatures: [],
      sourceDirectory: sourceDirectory,
      projection: try SwiftWebActorProjection(
        manifest: manifest,
        generatedDirectory: generatedDirectory,
        targetEnvironment: wasmEnvironment(
          embedded: true,
          availableModules: ["ActorSystemEmbedded"]
        )
      )
    )
    let destination = root.appendingPathComponent("materialized", isDirectory: true)
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    try projection.installProjectedOriginalSources(
      in: destination,
      fileWriter: GeneratedPackageFileWriter()
    )

    let projected = try String(
      contentsOf: destination.appendingPathComponent("Feature.swift"),
      encoding: .utf8
    )
    #expect(projected.contains("struct ClientHelper"))
    #expect(projected.contains("dependencyClientMarker"))
    #expect(!projected.contains("dependencyServerSecret"))
    #expect(!projected.contains("distributed actor SharedCounter"))
    #expect(
      !FileManager.default.fileExists(
        atPath: destination.appendingPathComponent("Actions/Secret.swift").path
      )
    )
    #expect(
      !FileManager.default.fileExists(
        atPath: destination.appendingPathComponent("App.swift").path
      )
    )
  }

  @Test
  func materializationTransactionRestoresBothRootsAfterCommitFailure() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "SwiftWebGeneratedPackageTransaction-\(UUID().uuidString)",
      isDirectory: true
    )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("Failed to remove temporary directory: \(error)")
      }
    }
    let generatedRoot = root.appendingPathComponent("generated", isDirectory: true)
    let nativeSource = root.appendingPathComponent("Sources/App", isDirectory: true)
    let nativeGenerated = nativeSource.appendingPathComponent(
      "ActorSystemGenerated",
      isDirectory: true
    )
    try write(
      "old generated root",
      to: generatedRoot.appendingPathComponent("marker.txt")
    )
    try write(
      "old native projection",
      to: nativeGenerated.appendingPathComponent("marker.txt")
    )
    let transaction = GeneratedPackageMaterializationTransaction(
      generatedPackageDirectory: generatedRoot,
      nativeSourceDirectory: nativeSource,
      beforeGeneratedRootCommit: {
        throw GeneratedPackageCommitFixtureError()
      }
    )
    try transaction.prepare()
    try write(
      "new generated root",
      to: transaction.stagingGeneratedPackageDirectory
        .appendingPathComponent("marker.txt")
    )
    try write(
      "new native projection",
      to: transaction.stagingNativeSourceDirectory
        .appendingPathComponent("ActorSystemGenerated/marker.txt")
    )

    #expect(throws: GeneratedPackageCommitFixtureError.self) {
      try transaction.commit()
    }

    #expect(
      try String(
        contentsOf: generatedRoot.appendingPathComponent("marker.txt"),
        encoding: .utf8
      ) == "old generated root"
    )
    #expect(
      try String(
        contentsOf: nativeGenerated.appendingPathComponent("marker.txt"),
        encoding: .utf8
      ) == "old native projection"
    )
    try transaction.discardPreparedArtifacts()
  }

  @Test
  func materializationTransactionRecoversAnInterruptedPreparedCommit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "SwiftWebGeneratedPackageRecovery-\(UUID().uuidString)",
      isDirectory: true
    )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("Failed to remove temporary directory: \(error)")
      }
    }
    let generatedRoot = root.appendingPathComponent("generated", isDirectory: true)
    let nativeSource = root.appendingPathComponent("Sources/App", isDirectory: true)
    let nativeGenerated = nativeSource.appendingPathComponent(
      "ActorSystemGenerated",
      isDirectory: true
    )
    try write("old generated root", to: generatedRoot.appendingPathComponent("marker.txt"))
    try write("old native projection", to: nativeGenerated.appendingPathComponent("marker.txt"))

    let interrupted = GeneratedPackageMaterializationTransaction(
      generatedPackageDirectory: generatedRoot,
      nativeSourceDirectory: nativeSource
    )
    try interrupted.prepare()
    try write(
      "new generated root",
      to: interrupted.stagingGeneratedPackageDirectory.appendingPathComponent("marker.txt")
    )
    let stagedNativeGenerated = interrupted.stagingNativeSourceDirectory
      .appendingPathComponent("ActorSystemGenerated", isDirectory: true)
    try write(
      "new native projection",
      to: stagedNativeGenerated.appendingPathComponent("marker.txt")
    )
    let journal = GeneratedPackageMaterializationTransaction.RecoveryJournal(
      version: 1,
      phase: .prepared,
      hadGeneratedPackage: true,
      hadNativeSources: true,
      generatedPackageDirectory: generatedRoot.path,
      nativeGeneratedSourceDirectory: nativeGenerated.path,
      stagingGeneratedPackageDirectory: interrupted.stagingGeneratedPackageDirectory.path,
      stagingNativeSourceDirectory: interrupted.stagingNativeSourceDirectory.path,
      generatedPackageBackupDirectory: interrupted.generatedPackageBackupDirectory.path,
      nativeGeneratedSourceBackupDirectory: interrupted.nativeGeneratedSourceBackupDirectory.path
    )
    try JSONEncoder().encode(journal).write(
      to: interrupted.recoveryJournalURL,
      options: .atomic
    )
    try FileManager.default.moveItem(
      at: generatedRoot,
      to: interrupted.generatedPackageBackupDirectory
    )
    try FileManager.default.moveItem(
      at: nativeGenerated,
      to: interrupted.nativeGeneratedSourceBackupDirectory
    )
    try FileManager.default.moveItem(
      at: stagedNativeGenerated,
      to: nativeGenerated
    )

    let recovered = GeneratedPackageMaterializationTransaction(
      generatedPackageDirectory: generatedRoot,
      nativeSourceDirectory: nativeSource
    )
    try recovered.prepare()

    #expect(
      try String(
        contentsOf: generatedRoot.appendingPathComponent("marker.txt"),
        encoding: .utf8
      ) == "old generated root"
    )
    #expect(
      try String(
        contentsOf: nativeGenerated.appendingPathComponent("marker.txt"),
        encoding: .utf8
      ) == "old native projection"
    )
    #expect(!FileManager.default.fileExists(atPath: recovered.recoveryJournalURL.path))
    try recovered.discardPreparedArtifacts()
  }

  @Test
  func materializationTransactionFinalizesAnInterruptedInstalledCommit() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(
      "SwiftWebGeneratedPackageInstalledRecovery-\(UUID().uuidString)",
      isDirectory: true
    )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("Failed to remove temporary directory: \(error)")
      }
    }
    let generatedRoot = root.appendingPathComponent("generated", isDirectory: true)
    let nativeSource = root.appendingPathComponent("Sources/App", isDirectory: true)
    let nativeGenerated = nativeSource.appendingPathComponent(
      "ActorSystemGenerated",
      isDirectory: true
    )
    try write("old generated root", to: generatedRoot.appendingPathComponent("marker.txt"))
    try write("old native projection", to: nativeGenerated.appendingPathComponent("marker.txt"))

    let interrupted = GeneratedPackageMaterializationTransaction(
      generatedPackageDirectory: generatedRoot,
      nativeSourceDirectory: nativeSource
    )
    try interrupted.prepare()
    try write(
      "new generated root",
      to: interrupted.stagingGeneratedPackageDirectory.appendingPathComponent("marker.txt")
    )
    let stagedNativeGenerated = interrupted.stagingNativeSourceDirectory
      .appendingPathComponent("ActorSystemGenerated", isDirectory: true)
    try write(
      "new native projection",
      to: stagedNativeGenerated.appendingPathComponent("marker.txt")
    )
    var journal = GeneratedPackageMaterializationTransaction.RecoveryJournal(
      version: 1,
      phase: .prepared,
      hadGeneratedPackage: true,
      hadNativeSources: true,
      generatedPackageDirectory: generatedRoot.path,
      nativeGeneratedSourceDirectory: nativeGenerated.path,
      stagingGeneratedPackageDirectory: interrupted.stagingGeneratedPackageDirectory.path,
      stagingNativeSourceDirectory: interrupted.stagingNativeSourceDirectory.path,
      generatedPackageBackupDirectory: interrupted.generatedPackageBackupDirectory.path,
      nativeGeneratedSourceBackupDirectory: interrupted.nativeGeneratedSourceBackupDirectory.path
    )
    try JSONEncoder().encode(journal).write(
      to: interrupted.recoveryJournalURL,
      options: .atomic
    )
    try FileManager.default.moveItem(
      at: generatedRoot,
      to: interrupted.generatedPackageBackupDirectory
    )
    try FileManager.default.moveItem(
      at: nativeGenerated,
      to: interrupted.nativeGeneratedSourceBackupDirectory
    )
    try FileManager.default.moveItem(
      at: stagedNativeGenerated,
      to: nativeGenerated
    )
    try FileManager.default.moveItem(
      at: interrupted.stagingGeneratedPackageDirectory,
      to: generatedRoot
    )
    journal.phase = .installed
    try JSONEncoder().encode(journal).write(
      to: interrupted.recoveryJournalURL,
      options: .atomic
    )

    let recovered = GeneratedPackageMaterializationTransaction(
      generatedPackageDirectory: generatedRoot,
      nativeSourceDirectory: nativeSource
    )
    try recovered.prepare()

    #expect(
      try String(
        contentsOf: generatedRoot.appendingPathComponent("marker.txt"),
        encoding: .utf8
      ) == "new generated root"
    )
    #expect(
      try String(
        contentsOf: nativeGenerated.appendingPathComponent("marker.txt"),
        encoding: .utf8
      ) == "new native projection"
    )
    #expect(!FileManager.default.fileExists(atPath: interrupted.generatedPackageBackupDirectory.path))
    #expect(!FileManager.default.fileExists(atPath: interrupted.nativeGeneratedSourceBackupDirectory.path))
    #expect(!FileManager.default.fileExists(atPath: recovered.recoveryJournalURL.path))
    try recovered.discardPreparedArtifacts()
  }

  @Test
  func rendersDependencyActorTargetsAndQualifiedAggregateBootstrap() throws {
    let root = URL(fileURLWithPath: "/tmp/swiftweb-format-fixture", isDirectory: true)
    let context = GeneratedPackageRenderContext(
      layout: GeneratedPackageLayout(
        appPackageDirectory: root,
        rootDirectory: root.appendingPathComponent("generated", isDirectory: true)
      ),
      swiftWebPackageDirectory: root,
      appPackageName: "SampleApp",
      appPackageDependencyName: "sample-app",
      appProductName: "SampleApp",
      serverProductName: "app-server",
      developmentServerProductName: "app-server-dev",
      devProductName: "SampleApp-dev",
      wasmRuntimeTargets: [],
      clientEnvironmentKeyTypeNames: [],
      wasmRuntimeProfile: .standard,
      embeddedUnicodeDataTablesLibraryPath: nil,
      nativeActorBootstrapTypeName: "SampleAppActorSystemBootstrap",
      clientActorBootstrapTypeName: "SampleAppActorSystemBootstrap",
      appActorCustomConditions: ["ROOT_ACTORS", "SWIFTWEB_ACTORS"],
      appActorUpcomingFeatures: ["RootUpcoming"],
      appActorExperimentalFeatures: [],
      actorDependencyTargets: [
        GeneratedActorDependencyTarget(
          moduleName: "CommonActors",
          dependencyModuleNames: [],
          bootstrapTypeName: "CommonActorsActorSystemBootstrap"
        ),
        GeneratedActorDependencyTarget(
          moduleName: "SharedActors",
          dependencyModuleNames: ["CommonActors"],
          clientImportedModuleNames: ["ActorRuntime", "JavaScriptKit", "SwiftWebUI"],
          customConditions: ["SHARED_ACTORS", "SWIFTWEB_ACTORS"],
          experimentalFeatures: ["SharedExperimental"],
          bootstrapTypeName: "SharedActorsActorSystemBootstrap"
        ),
      ]
    )

    let packageSource = try WasmPackageManifestFormat().packageSwift(context: context)
    let resolverSource = try WasmActorResolverRegistryFormat().resolverRegistrySwift(
      context: context
    )
    let launcherSource = ServerPackageFormat.serverLauncherSwift(
      context: context,
      installsDevelopmentHooks: false
    )

    #expect(packageSource.contains("name: \"CommonActors\""))
    #expect(packageSource.contains("name: \"SharedActors\""))
    #expect(packageSource.contains("path: \"Sources/CommonActors\""))
    #expect(packageSource.contains("path: \"Sources/SharedActors\""))
    #expect(packageSource.contains("\"CommonActors\","))
    let appTargetStart = try #require(
      packageSource.range(of: "let appClientTarget = Target.target(")
    )
    let appTargetEnd = try #require(
      packageSource.range(
        of: "swiftSettings: appActorSwiftSettings",
        range: appTargetStart.lowerBound..<packageSource.endIndex
      )
    )
    let appTargetDeclaration = packageSource[
      appTargetStart.lowerBound..<appTargetEnd.upperBound
    ]
    #expect(appTargetDeclaration.contains("name: \"SampleApp\""))
    #expect(appTargetDeclaration.contains("swiftSettings: appActorSwiftSettings"))
    let sharedTargetStart = try #require(
      packageSource.range(of: "let sharedActorsTarget = Target.target(")
    )
    let sharedTargetEnd = try #require(
      packageSource.range(
        of: "path: \"Sources/SharedActors\"",
        range: sharedTargetStart.lowerBound..<packageSource.endIndex
      )
    )
    let sharedTargetDeclaration = packageSource[
      sharedTargetStart.lowerBound..<sharedTargetEnd.upperBound
    ]
    #expect(sharedTargetDeclaration.contains("\"CommonActors\","))
    #expect(sharedTargetDeclaration.contains("\"JavaScriptKit\","))
    #expect(sharedTargetDeclaration.contains("\"SwiftWebUI\","))
    #expect(!sharedTargetDeclaration.contains("ActorRuntime"))
    let sharedActorSettings = try #require(
      packageSource.range(
        of: "swiftSettings: sharedActorsTargetSwiftSettings",
        range: sharedTargetStart.lowerBound..<packageSource.endIndex
      )
    )
    #expect(sharedActorSettings.lowerBound > sharedTargetEnd.lowerBound)
    #expect(packageSource.contains("let appActorSwiftSettings: [SwiftSetting] = actorSwiftSettings + ["))
    #expect(packageSource.contains(".define(\"ROOT_ACTORS\")"))
    #expect(packageSource.contains(".enableUpcomingFeature(\"RootUpcoming\")"))
    #expect(packageSource.contains("let sharedActorsTargetSwiftSettings: [SwiftSetting] = actorSwiftSettings + ["))
    #expect(packageSource.contains(".define(\"SHARED_ACTORS\")"))
    #expect(packageSource.contains(".enableExperimentalFeature(\"SharedExperimental\")"))
    #expect(
      packageSource.components(separatedBy: ".define(\"SWIFTWEB_ACTORS\")").count == 2
    )
    #expect(!packageSource.contains("SWIFTWEB_LEGACY_ACTORS"))
    #expect(!packageSource.contains("ActorSystemCompatibility"))
    #expect(resolverSource.contains("import CommonActors"))
    #expect(resolverSource.contains("import SharedActors"))
    #expect(resolverSource.contains("SampleAppActorSystemBootstrap.self"))
    #expect(
      resolverSource.contains(
        "CommonActors.CommonActorsActorSystemBootstrap.self"
      )
    )
    #expect(
      resolverSource.contains(
        "SharedActors.SharedActorsActorSystemBootstrap.self"
      )
    )
    let sharedRegistration = try #require(
      launcherSource.range(
        of: "try WebActorSystem.shared.registerGeneratedBootstrap(SampleAppActorSystemBootstrap.self)"
      )
    )
    let appInitialization = try #require(
      launcherSource.range(of: "let app = SampleApp()")
    )
    let appRegistration = try #require(
      launcherSource.range(
        of: "try app.actorSystem.registerGeneratedBootstrap(SampleAppActorSystemBootstrap.self)"
      )
    )
    #expect(sharedRegistration.lowerBound < appInitialization.lowerBound)
    #expect(appInitialization.lowerBound < appRegistration.lowerBound)
  }

  @Test
  func generatedProfilesRejectLegacyActorContractsBeforeRendering() {
    let root = URL(fileURLWithPath: "/tmp/swiftweb-legacy-contract-fixture", isDirectory: true)
    for profile in [SwiftWebWasmRuntimeProfile.standard, .embedded] {
      let context = GeneratedPackageRenderContext(
        layout: GeneratedPackageLayout(
          appPackageDirectory: root,
          rootDirectory: root.appendingPathComponent("generated", isDirectory: true)
        ),
        swiftWebPackageDirectory: root,
        appPackageName: "SampleApp",
        appPackageDependencyName: "sample-app",
        appProductName: "SampleApp",
        serverProductName: "app-server",
        developmentServerProductName: "app-server-dev",
        devProductName: "SampleApp-dev",
        wasmRuntimeTargets: [
          WasmRuntimeTargetDeclaration(
            targetName: "SampleAppWasmRuntime",
            bundleID: ClientBundleID("sample-app"),
            componentTypeNames: ["ClientSample"],
            actorContracts: [
              ClientActorContractDeclaration(
                serviceTypeName: "SampleServiceProtocol",
                isLegacyExistential: true
              )
            ],
            linkMode: .standalone
          )
        ],
        clientEnvironmentKeyTypeNames: [],
        wasmRuntimeProfile: profile,
        embeddedUnicodeDataTablesLibraryPath: profile == .embedded
          ? "/tmp/libswiftUnicodeDataTables.a"
          : nil,
        nativeActorBootstrapTypeName: nil,
        clientActorBootstrapTypeName: nil,
        appActorCustomConditions: [],
        appActorUpcomingFeatures: [],
        appActorExperimentalFeatures: [],
        actorDependencyTargets: []
      )

      #expect(throws: SwiftWebGeneratedPackageMaterializerError.self) {
        try WasmActorResolverRegistryFormat().resolverRegistrySwift(context: context)
      }
    }
  }

  @Test
  func materializesGeneratedBuildPackage() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      """
      public struct ClientSample: ClientComponent {
          @RemoteActor private var service: SampleService

          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )
    try write(
      "public struct ClientBadge: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientBadge.swift")
    )
    try write(
      """
      public struct ClientExtensionBox {
          public init() {}
      }

      extension ClientExtensionBox: ClientComponent {}
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientExtensionBox.swift")
    )
    let sampleActorSourceDirectory = appPackage.appendingPathComponent(
      "Sources/SampleApp",
      isDirectory: true
    )
    let sampleActorSource = sampleActorSourceDirectory.appendingPathComponent(
      "Services/SampleService.swift"
    )
    try write(
      """
      import Distributed
      import SwiftWebActors

      distributed actor SampleService {
          typealias ActorSystem = WebActorSystem

          distributed func ping() async throws -> String {
              "pong"
          }
      }
      """,
      to: sampleActorSource
    )
    let fixtureActors = try ActorSourceScanner.scan(
      sourceFiles: [sampleActorSource],
      moduleName: "SampleApp",
      includingActorSystemTypes: ["WebActorSystem"]
    )
    let fixtureToolchain = try SwiftWebHostSwiftToolchain.resolve(
      configuration: SwiftWebDevRuntimeConfiguration(packageDirectory: appPackage)
    )
    let fixtureToolchainFingerprint = try ActorToolchainFingerprint.compute(
      swiftCompiler: fixtureToolchain.swiftCompilerURL
    )
    let fixtureCompilerTargets = fixtureActors.flatMap { actor in
      actor.methods.map { method in
        ActorCompilerTargetMapping(
          key: ActorCompilerTargetKey(
            actorSymbol: actor.symbol,
            canonicalMethodSignature: method.canonicalSignature
          ),
          targetIdentifier: "fixture:\(actor.symbol):\(method.canonicalSignature)"
        )
      }
    }
    let fixtureSchema = try ActorSchemaReconciler.reconcile(
      actors: fixtureActors,
      packageIdentity: "sampleapp",
      moduleName: "SampleApp",
      toolchainFingerprint: fixtureToolchainFingerprint,
      compilerTargets: fixtureCompilerTargets,
      sourceRoot: sampleActorSourceDirectory,
      existing: ActorSchemaLock(packageIdentity: "sampleapp")
    )
    let fixtureSchemaEncoder = JSONEncoder()
    fixtureSchemaEncoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
    try fixtureSchemaEncoder.encode(fixtureSchema).write(
      to: appPackage.appendingPathComponent("ActorSchema.lock"),
      options: .atomic
    )
    try write(
      "struct Page {}", to: appPackage.appendingPathComponent("Sources/SampleApp/Routes/Page.swift")
    )
    try write(
      "struct Service {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/Actions/Service.swift"))
    try write(
      """
      {
        "pins" : [
          {
            "identity" : "javascriptkit",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/swiftwasm/JavaScriptKit.git",
            "state" : {
              "revision" : "abc",
              "version" : "0.55.0"
            }
          },
          {
            "identity" : "swift-syntax",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/swiftlang/swift-syntax.git",
            "state" : {
              "revision" : "def",
              "version" : "602.0.0"
            }
          },
          {
            "identity" : "vapor",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/vapor/vapor.git",
            "state" : {
              "revision" : "ghi"
            }
          },
          {
            "identity" : "swift-actor-runtime",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/1amageek/swift-actor-runtime.git",
            "state" : {
              "revision" : "jkl",
              "version" : "0.6.0"
            }
          }
        ],
        "version" : 3
      }
      """,
      to: appPackage.appendingPathComponent("Package.resolved")
    )
    try write(
      "import SampleApp\n@main struct Runtime { static func main() {} }",
      to: appPackage.appendingPathComponent(
        ".swiftweb/generated/Sources/SampleWasmRuntime/Runtime.swift")
    )
    try write(
      "legacy", to: appPackage.appendingPathComponent(".swiftweb/generated/.materialize.lock"))

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmSplitBuildStrategy: .resolvedBundles
    )
    .materialize()

    #expect(generatedPackage.appProductName == "SampleApp")
    #expect(generatedPackage.serverProductName == "app-server")
    #expect(generatedPackage.developmentServerProductName == "app-server-dev")
    #expect(generatedPackage.devProductName == "SampleApp-dev")
    #expect(generatedPackage.wasmProductNames == ["sample-app-wasm-runtime"])
    #expect(generatedPackage.packageDirectory.lastPathComponent == "server")
    #expect(generatedPackage.devPackageDirectory.lastPathComponent == "dev")
    #expect(generatedPackage.wasmPackageDirectory.lastPathComponent == "wasm")
    #expect(
      !FileManager.default.fileExists(
        atPath: generatedPackage.rootDirectory.appendingPathComponent(".materialize.lock").path
      ))

    let serverPackageSwift = try String(
      contentsOf: generatedPackage.packageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    let devPackageSwift = try String(
      contentsOf: generatedPackage.devPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    #expect(
      FileManager.default.fileExists(
        atPath: generatedPackage.packageDirectory.appendingPathComponent("Package.resolved").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedPackage.devPackageDirectory.appendingPathComponent("Package.resolved").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved")
          .path
      ))
    let wasmPackageResolved = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    #expect(!wasmPackageResolved.contains("javascriptkit"))
    #expect(!wasmPackageResolved.contains("swift-syntax"))
    #expect(!wasmPackageResolved.contains("vapor"))
    #expect(!wasmPackageResolved.contains("swift-actor-runtime"))
    #expect(
      serverPackageSwift.contains(
        ".executable(name: \"app-server\", targets: [\"AppServerLauncher\"])"))
    #expect(serverPackageSwift.contains(#".package(path: "../../..")"#))
    #expect(serverPackageSwift.contains(#".package(path: "../../../../swift-web"),"#))
    #expect(
      !serverPackageSwift.contains(
        ".executable(name: \"SampleApp-dev\", targets: [\"SwiftWebDevLauncher\"])"))
    #expect(!serverPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
    #expect(!serverPackageSwift.contains(swiftWebPackage.path))
    #expect(!serverPackageSwift.contains("https://github.com/1amageek/swift-web.git"))
    #expect(!serverPackageSwift.contains("SwiftWebDevLauncher"))
    #expect(!serverPackageSwift.contains("SwiftWebDevelopment"))
    #expect(!serverPackageSwift.contains("AppDevelopmentServerLauncher"))
    #expect(!serverPackageSwift.contains("sample-wasm-runtime"))
    #expect(!serverPackageSwift.contains("JavaScriptKit"))
    #expect(!serverPackageSwift.contains("swift-actor-runtime"))

    #expect(
      devPackageSwift.contains(
        ".executable(name: \"SampleApp-dev\", targets: [\"SwiftWebDevLauncher\"])"))
    #expect(
      devPackageSwift.contains(
        ".executable(name: \"app-server-dev\", targets: [\"AppDevelopmentServerLauncher\"])"))
    #expect(!devPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
    #expect(!devPackageSwift.contains(swiftWebPackage.path))
    #expect(!devPackageSwift.contains("https://github.com/1amageek/swift-web.git"))
    #expect(devPackageSwift.contains(#".package(path: "../../../../swift-web")"#))
    #expect(devPackageSwift.contains(#".package(path: "../../..")"#))
    #expect(
      devPackageSwift.contains(".product(name: \"SwiftWebDevelopment\", package: \"swift-web\")"))
    #expect(
      devPackageSwift.contains(".product(name: \"SwiftWebHTTPServerHost\", package: \"swift-web\")"))
    #expect(
      devPackageSwift.contains(
        ".product(name: \"SwiftWebDevelopmentHooks\", package: \"swift-web\")"))
    #expect(!devPackageSwift.contains("sample-wasm-runtime"))

    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-wasm-runtime\", targets: [\"SampleAppWasmRuntime\"])"))
    #expect(!wasmPackageSwift.contains(".package(path: \"\(swiftHTMLPackage.path)\""))
    #expect(
      !wasmPackageSwift.contains(".package(url: \"https://github.com/1amageek/swift-html.git\""))
    #expect(
      !wasmPackageSwift.contains(".package(url: \"https://github.com/swiftwasm/JavaScriptKit.git\"")
    )
    #expect(!wasmPackageSwift.contains("swift-syntax"))
    #expect(!wasmPackageSwift.contains("BridgeJSMacros"))
    #expect(!wasmPackageSwift.contains("swift-actor-runtime"))
    #expect(!wasmPackageSwift.contains(".package(path: \"\(swiftWebPackage.path)\""))
    #expect(!wasmPackageSwift.contains(".package(path: \"\(appPackage.path)\""))
    #expect(!wasmPackageSwift.contains("AppServerLauncher"))
    #expect(!wasmPackageSwift.contains("SwiftWebDevLauncher"))
    #expect(wasmPackageSwift.contains("let swiftHTMLTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftHTML\""))
    #expect(!wasmPackageSwift.contains(".product(name: \"SwiftHTML\", package: \"swift-html\")"))
    #expect(wasmPackageSwift.contains("let swiftWebActorsTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebActors\""))
    #expect(
      wasmPackageSwift.contains(
        """
        let actorSwiftSettings: [SwiftSetting] = swiftSettings + [
            .define("SWIFTWEB_ACTORS"),
        ]
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebActorsTarget = Target.target(
            name: "SwiftWebActors",
            dependencies: [
                "ActorSystemCore",
                "ActorSystemDistributed",
                "SwiftHTML",
            ],
            path: "Sources/SwiftWebActors",
            swiftSettings: actorSwiftSettings
        )
        """))
    #expect(!wasmPackageSwift.contains("ActorRuntime"))
    #expect(!wasmPackageSwift.contains("ActorSystemCompatibility"))
    #expect(!wasmPackageSwift.contains("SWIFTWEB_LEGACY_ACTORS"))
    #expect(wasmPackageSwift.contains("let actorSystemCoreTarget = Target.target("))
    #expect(wasmPackageSwift.contains("name: \"ActorSystemDistributed\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/ActorSystemDistributed\""))
    #expect(wasmPackageSwift.contains("let swiftWebUITarget = Target.target("))
    #expect(wasmPackageSwift.contains("let swiftWebUIThemeTarget = Target.target("))
    #expect(wasmPackageSwift.contains("let cJavaScriptKitTarget = Target.target("))
    #expect(wasmPackageSwift.contains("let javaScriptKitTarget = Target.target("))
    #expect(wasmPackageSwift.contains("let swiftWebUIRuntimeTarget = Target.target("))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebUITheme\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/SwiftWebUIRuntime\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/JavaScriptKit\""))
    #expect(wasmPackageSwift.contains("path: \"Sources/_CJavaScriptKit\""))
    #expect(wasmPackageSwift.contains("\"JavaScriptKit\""))
    #expect(
      wasmPackageSwift.contains(
        """
        let appClientTarget = Target.target(
            name: "SampleApp",
            dependencies: [
                "ActorSystemCore",
                "ActorSystemDistributed",
                "JavaScriptKit",
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebStyle",
                "SwiftWebUI",
                "SwiftWebUIRuntime",
                "SwiftWebUITheme",
            ],
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebUIThemeTarget = Target.target(
            name: "SwiftWebUITheme",
            dependencies: [
                "SwiftHTML",
                "SwiftWebStyle",
            ],
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebUITarget = Target.target(
            name: "SwiftWebUI",
            dependencies: [
                "SwiftHTML",
                "SwiftWebActors",
                "SwiftWebStyle",
                "SwiftWebUITheme",
            ],
        """))
    #expect(
      wasmPackageSwift.contains(
        """
        let swiftWebUIRuntimeTarget = Target.target(
            name: "SwiftWebUIRuntime",
            dependencies: [
                "ActorSystemCore",
                "ActorSystemDistributed",
                "SwiftHTML",
                "JavaScriptKit",
                "SwiftWebActors",
                "SwiftWebStyle",
            ],
        """))
    #expect(wasmPackageSwift.contains("--export=swiftweb_snapshot_state"))
    #expect(wasmPackageSwift.contains("--export=swiftweb_restore_state"))
    #expect(wasmPackageSwift.contains("--export=swiftweb_shutdown"))
    #expect(wasmPackageSwift.contains("--export=swiftweb_shutdown_status"))
    #expect(wasmPackageSwift.contains("let swiftHTMLSwiftSettings: [SwiftSetting]"))
    #expect(wasmPackageSwift.contains("swiftSettings: swiftHTMLSwiftSettings"))
    // The client hydration walk recurses the component tree; deep trees overflow
    // the default 1MB wasm stack. Pin the larger stack so it can't silently regress.
    #expect(wasmPackageSwift.contains("stack-size=16777216"))
    #expect(!wasmPackageSwift.contains("exclude: [\"README.md\"]"))

    let serverSources = generatedPackage.packageDirectory.appendingPathComponent("Sources")
    let devSources = generatedPackage.devPackageDirectory.appendingPathComponent("Sources")
    let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
    #expect(
      FileManager.default.fileExists(
        atPath: serverSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: serverSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: devSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: devSources.appendingPathComponent(
          "AppDevelopmentServerLauncher/ServerLauncher.swift"
        ).path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: serverSources.appendingPathComponent(
          "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientSample.swift").path
      ))
    let copiedClientSample = try String(
      contentsOf: wasmSources.appendingPathComponent("SampleApp/ClientSample.swift"),
      encoding: .utf8
    )
    #expect(!copiedClientSample.contains("@RemoteActor"))
    #expect(copiedClientSample.contains("private var service: SampleService {"))
    #expect(copiedClientSample.contains("SwiftWebActorBinding.resolve("))
    #expect(
      copiedClientSample.contains(
        "SwiftWebActorContractKey((SampleService).self)"
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientBadge.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/ClientExtensionBox.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/Services/SampleService.swift")
          .path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent(
          "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
        ).path
      ))
    let wasmEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
      encoding: .utf8
    )
    let wasmActorResolvers = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleApp/SwiftWebGeneratedActorResolvers.swift"),
      encoding: .utf8
    )
    let serverLauncher = try String(
      contentsOf: serverSources.appendingPathComponent("AppServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    let developmentServerLauncher = try String(
      contentsOf: devSources.appendingPathComponent(
        "AppDevelopmentServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    let developmentLauncher = try String(
      contentsOf: devSources.appendingPathComponent("SwiftWebDevLauncher/DevLauncher.swift"),
      encoding: .utf8
    )
    #expect(serverLauncher.contains("SWIFTWEB_WASM_SCRATCH_PATH"))
    #expect(serverLauncher.contains("import SwiftWebHTTPServerHost"))
    #expect(serverLauncher.contains("scratchDirectory: wasmScratchDirectory"))
    #expect(!serverLauncher.contains("SwiftWebDevelopmentHooksRuntime.install()"))
    #expect(developmentServerLauncher.contains("import SwiftWebHTTPServerHost"))
    #expect(developmentServerLauncher.contains("import SwiftWebDevelopmentHooks"))
    #expect(developmentServerLauncher.contains("SwiftWebDevelopmentHooksRuntime.install()"))
    #expect(developmentLauncher.contains("SWIFT_WEB_DEV_PRODUCT"))
    #expect(developmentLauncher.contains("\"app-server\""))
    #expect(!developmentLauncher.contains("\"app-server-dev\""))
    #expect(!developmentLauncher.contains("app-server-dev-dev"))
    #expect(wasmEntrypoint.contains("import SwiftWebActors"))
    #expect(
      wasmEntrypoint.contains("SwiftWebGeneratedActorResolvers.sampleAppWasmRuntime()")
    )
    #expect(wasmActorResolvers.contains("SwiftWebActorResolverRegistry(["))
    #expect(wasmActorResolvers.contains("SwiftWebActorResolver("))
    #expect(
      wasmActorResolvers.contains(
        "SwiftWebActorContractKey(SampleService.self)"
      ))
    #expect(wasmActorResolvers.contains("actorContract: SampleService.self"))
    #expect(wasmEntrypoint.contains("actorResolverRegistry: sampleAppWasmRuntimeActorResolvers"))
    #expect(wasmEntrypoint.contains("import SwiftWebUI"))
    #expect(wasmEntrypoint.contains("import SwiftWebUIRuntime"))
    #expect(wasmEntrypoint.contains("ClientBundleRuntimeEntrypoint"))
    #expect(wasmEntrypoint.contains("ClientComponentRegistration("))
    #expect(wasmEntrypoint.contains("ClientSample.self"))
    #expect(wasmEntrypoint.contains("ClientBadge.self"))
    #expect(wasmEntrypoint.contains("ClientExtensionBox.self"))
    #expect(wasmEntrypoint.contains("makeSwiftWebWasmRoot"))
    #expect(wasmEntrypoint.contains("Root: ClientRuntimeBootstrapInitializable"))
    #expect(wasmEntrypoint.contains("try Root(bootstrap: request)"))
    #expect(!wasmEntrypoint.contains(" as? "))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/Core/HTML.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/Rendering/HTMLRenderer.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/SwiftHTML.docc").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftHTML/Preview").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebActors/LegacyWebActorSystem.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUI/Text.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUITheme/ThemeToken.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent(
          "JavaScriptKit/FundamentalObjects/JSObject.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("_CJavaScriptKit/include/_CJavaScriptKit.h").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("JavaScriptKit/Macros.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("JavaScriptKit/Runtime").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("JavaScriptKit/Documentation.docc").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUI/README.md").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SwiftWebUIRuntime/README.md").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/App.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/Routes/Page.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleApp/Actions/Service.swift").path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: wasmSources.appendingPathComponent("SampleAppWasmRuntime/Runtime.swift").path
      ))
    #expect(!serverLauncher.contains("SwiftWebDevHotReload"))
    #expect(!serverLauncher.contains("__swiftWebDevReload"))
    #expect(!serverLauncher.contains("SWIFTWEB_DEV_TOKEN"))
  }

  @Test
  func materializesEmbeddedWasmRuntimeProfile() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebEmbeddedWasmMaterializerTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
              .library(name: "SwiftHTMLClientRuntime", targets: ["SwiftHTMLClientRuntime"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
              .target(name: "SwiftHTMLClientRuntime"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try writeSwiftHTMLClientRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let generated = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmRuntimeProfile: .embedded
    )
    .materialize()
    let manifest = try String(
      contentsOf: generated.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    let sources = generated.wasmPackageDirectory.appendingPathComponent(
      "Sources",
      isDirectory: true
    )
    let entrypoint = try String(
      contentsOf: sources.appendingPathComponent(
        "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
      ),
      encoding: .utf8
    )

    #expect(manifest.contains("let actorSystemCoreTarget = Target.target("))
    #expect(manifest.contains("name: \"ActorSystemEmbedded\""))
    #expect(manifest.contains("path: \"Sources/ActorSystemEmbedded\""))
    #expect(!manifest.contains("ActorRuntime"))
    #expect(!manifest.contains("ActorSystemCompatibility"))
    #expect(!manifest.contains("SWIFTWEB_LEGACY_ACTORS"))
    #expect(!manifest.contains("swift-actor-runtime"))
    #expect(!manifest.contains(".define(\"SWIFTWEB_ACTORS\")"))
    #expect(manifest.contains("\"ActorSystemEmbedded\","))
    #expect(entrypoint.contains("typeName: \"ClientSample\""))
    #expect(entrypoint.contains("Root: ClientRuntimeBootstrapInitializable"))
    #expect(entrypoint.contains("try Root(bootstrap: request)"))
    #expect(entrypoint.contains("@_cdecl(\"swiftweb_shutdown\")"))
    #expect(entrypoint.contains("@_cdecl(\"swiftweb_shutdown_status\")"))
    #expect(!entrypoint.contains("String(reflecting:"))
    #expect(!entrypoint.contains(" as? "))
    #expect(
      FileManager.default.fileExists(
        atPath: sources.appendingPathComponent("ActorSystemCore/ActorSystemCore.swift").path
      )
    )
    #expect(
      FileManager.default.fileExists(
        atPath: sources.appendingPathComponent("ActorSystemEmbedded/EmbeddedActorSystem.swift").path
      )
    )
    #expect(
      !FileManager.default.fileExists(
        atPath: sources.appendingPathComponent("ActorSystemDistributed").path
      )
    )
    #expect(
      FileManager.default.fileExists(
        atPath: sources.appendingPathComponent(
          "SampleApp/SwiftWebGeneratedActorResolvers.swift"
        ).path
      )
    )
  }

  @Test
  func materializationFallsBackToSwiftWebPackageResolvedWhenAppHasNoLockfile() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageResolvedFallbackTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      """
      {
        "pins" : [
          {
            "identity" : "swift-http-server",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/swift-server/swift-http-server",
            "state" : {
              "branch" : "main",
              "revision" : "b1c4f775dfbdc74800c0f29fda79c8984a5e9073"
            }
          },
          {
            "identity" : "vapor",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/vapor/vapor.git",
            "state" : {
              "revision" : "8cfd55759c9f9e30ebdb95e30a3e80d96563f3fd"
            }
          },
          {
            "identity" : "swift-actor-runtime",
            "kind" : "remoteSourceControl",
            "location" : "https://github.com/1amageek/swift-actor-runtime.git",
            "state" : {
              "revision" : "actor-runtime-revision",
              "version" : "0.6.0"
            }
          }
        ],
        "version" : 3
      }
      """,
      to: swiftWebPackage.appendingPathComponent("Package.resolved")
    )
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage
    )
    .materialize()

    let serverPackageResolved = try String(
      contentsOf: generatedPackage.packageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    let devPackageResolved = try String(
      contentsOf: generatedPackage.devPackageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    let wasmPackageResolved = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.resolved"),
      encoding: .utf8
    )
    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )

    #expect(serverPackageResolved.contains("\"identity\" : \"swift-http-server\""))
    #expect(serverPackageResolved.contains("\"branch\" : \"main\""))
    #expect(devPackageResolved.contains("\"identity\" : \"swift-http-server\""))
    #expect(devPackageResolved.contains("\"branch\" : \"main\""))
    #expect(!wasmPackageResolved.contains("\"identity\" : \"swift-actor-runtime\""))
    #expect(!wasmPackageResolved.contains("\"identity\" : \"swift-http-server\""))
    #expect(!wasmPackageResolved.contains("\"identity\" : \"vapor\""))
    #expect(!wasmPackageSwift.contains("swift-actor-runtime"))
  }

  @Test
  func serializesConcurrentMaterialization() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageConcurrentTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let errors = Mutex<[String]>([])
    await withTaskGroup(of: Void.self) { group in
      for _ in 0..<2 {
        group.addTask {
          do {
            _ = try SwiftWebGeneratedPackageMaterializer(
              appPackageDirectory: appPackage
            )
            .materialize()
          } catch {
            errors.withLock {
              $0.append(String(describing: error))
            }
          }
        }
      }
    }

    let capturedErrors = errors.withLock { $0 }
    #expect(capturedErrors.isEmpty)
    #expect(
      !FileManager.default.fileExists(
        atPath: appPackage.appendingPathComponent(".swiftweb/generated/.materialize.lock").path
      ))

    let generatedSources =
      appPackage
      .appendingPathComponent(".swiftweb/generated/wasm/Sources", isDirectory: true)
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SampleApp/ClientSample.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent(
          "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"
        ).path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftHTML/Core/HTML.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftWebActors/LegacyWebActorSystem.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftWebUI/Text.swift").path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("SwiftWebUIRuntime/RuntimeEntrypoint.swift")
          .path
      ))
    #expect(
      FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent(
          "JavaScriptKit/FundamentalObjects/JSObject.swift"
        ).path
      ))
    #expect(
      !FileManager.default.fileExists(
        atPath: generatedSources.appendingPathComponent("JavaScriptKit/Macros.swift").path
      ))
  }

  @Test
  func materializesSplitBundlesFromClientComponentContracts() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageSplitBundleTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientShell: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientShell.swift")
    )
    try write(
      """
      public struct ClientChart: ClientComponent {
          public static let loadPolicy: LoadPolicy = .visible
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientChart.swift")
    )
    try write(
      """
      public struct ClientEditor: ClientComponent {
          public static let loadPolicy: LoadPolicy = .interaction
          public static let bundle: BundlePolicy = .named("editing")
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientEditor.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmSplitBuildStrategy: .resolvedBundles
    )
    .materialize()

    #expect(generatedPackage.wasmProductNames.contains("sample-app-wasm-runtime"))
    #expect(generatedPackage.wasmProductNames.contains("named-editing-wasm-runtime"))
    #expect(generatedPackage.wasmProductNames.count == 3)

    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-wasm-runtime\", targets: [\"SampleAppWasmRuntime\"])"))
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"named-editing-wasm-runtime\", targets: [\"NamedEditingWasmRuntime\"])")
    )

    let serverLauncher = try String(
      contentsOf: generatedPackage.packageDirectory
        .appendingPathComponent("Sources/AppServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    #expect(serverLauncher.contains("id: \"named-editing\""))
    #expect(serverLauncher.contains("componentTypeNames: [\"ClientEditor\"]"))
    #expect(serverLauncher.contains("id: \"component-"))
    #expect(serverLauncher.contains("componentTypeNames: [\"ClientChart\"]"))

    let wasmSources = generatedPackage.wasmPackageDirectory.appendingPathComponent("Sources")
    let mainEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "SampleAppWasmRuntime/SampleAppWasmRuntime.swift"),
      encoding: .utf8
    )
    let namedEntrypoint = try String(
      contentsOf: wasmSources.appendingPathComponent(
        "NamedEditingWasmRuntime/NamedEditingWasmRuntime.swift"),
      encoding: .utf8
    )
    #expect(mainEntrypoint.contains("ClientShell.self"))
    #expect(!mainEntrypoint.contains("ClientChart.self"))
    #expect(!mainEntrypoint.contains("ClientEditor.self"))
    #expect(namedEntrypoint.contains("ClientEditor.self"))

    let splitEntrypoints = try FileManager.default.contentsOfDirectory(
      at: wasmSources,
      includingPropertiesForKeys: [.isDirectoryKey]
    )
    .filter { $0.lastPathComponent.hasPrefix("Component") }
    .map { directory in
      try String(
        contentsOf: directory.appendingPathComponent("\(directory.lastPathComponent).swift"),
        encoding: .utf8
      )
    }
    #expect(splitEntrypoints.count == 1)
    #expect(splitEntrypoints.first?.contains("ClientChart.self") == true)
  }

  @Test
  func coalescesPolicyBundlesWhenStaticLinkFallbackIsSelected() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageCoalescedTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientShell: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientShell.swift")
    )
    try write(
      """
      public struct ClientChart: ClientComponent {
          public static let loadPolicy: LoadPolicy = .visible
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientChart.swift")
    )
    try write(
      """
      public struct ClientEditor: ClientComponent {
          public static let loadPolicy: LoadPolicy = .interaction
          public static let bundle: BundlePolicy = .named("editing")
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientEditor.swift")
    )
    try write(
      """
      public struct ClientInspector: ClientComponent {
          public static let loadPolicy: LoadPolicy = .manual
          public static let bundle: BundlePolicy = .shared("tools")
          public init() {}
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientInspector.swift")
    )
    try write(
      """
      public struct ClientTile: ClientComponent {
          public init() {}
      }

      public struct ClientUsageSamples {
          public init() {}

          public func render() {
              _ = ClientTile().loadPolicy(.visible)
              _ = ClientTile().loadPolicy(.visible).bundle(.shared("left"))
              _ = ClientTile().loadPolicy(.visible).bundle(.shared("right"))
              _ = ClientTile().loadPolicy(.manual).bundle(.shared("tools"))
          }
      }
      """,
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientUsageSamples.swift")
    )

    let generatedPackage = try SwiftWebGeneratedPackageMaterializer(
      appPackageDirectory: appPackage,
      wasmSplitBuildStrategy: .coalescedPolicyBundles
    )
    .materialize()

    #expect(
      generatedPackage.wasmProductNames == [
        "sample-app-wasm-runtime",
        "sample-app-visible-wasm-runtime",
        "sample-app-interaction-wasm-runtime",
        "sample-app-manual-wasm-runtime",
      ])
    #expect(generatedPackage.wasmRuntimes.count == 4)
    #expect(generatedPackage.wasmRuntimes[0].linkMode == .standalone)
    #expect(
      generatedPackage.wasmRuntimes.dropFirst().allSatisfy {
        $0.linkMode == .coalescedStaticFallback
      })
    let visibleRuntime = try #require(
      generatedPackage.wasmRuntimes.first {
        $0.productName == "sample-app-visible-wasm-runtime"
      })
    #expect(visibleRuntime.componentTypeNames.filter { $0 == "ClientTile" }.count == 1)
    #expect(
      generatedPackage.wasmRuntimes.flatMap(\.componentTypeNames).sorted() == [
        "ClientChart",
        "ClientEditor",
        "ClientInspector",
        "ClientShell",
        "ClientTile",
        "ClientTile",
      ])

    let wasmPackageSwift = try String(
      contentsOf: generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift"),
      encoding: .utf8
    )
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-visible-wasm-runtime\", targets: [\"SampleAppVisibleWasmRuntime\"])"
      ))
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-interaction-wasm-runtime\", targets: [\"SampleAppInteractionWasmRuntime\"])"
      ))
    #expect(
      wasmPackageSwift.contains(
        ".executable(name: \"sample-app-manual-wasm-runtime\", targets: [\"SampleAppManualWasmRuntime\"])"
      ))
    #expect(!wasmPackageSwift.contains("named-editing-wasm-runtime"))
    #expect(!wasmPackageSwift.contains("shared-tools-wasm-runtime"))

    let serverLauncher = try String(
      contentsOf: generatedPackage.packageDirectory
        .appendingPathComponent("Sources/AppServerLauncher/ServerLauncher.swift"),
      encoding: .utf8
    )
    #expect(serverLauncher.contains("id: \"named-editing\""))
    #expect(serverLauncher.contains("id: \"shared-tools\""))
    #expect(serverLauncher.contains("id: \"shared-left\""))
    #expect(serverLauncher.contains("id: \"shared-right\""))
    #expect(serverLauncher.contains("id: \"component-"))
    #expect(
      serverLauncher.contains(
        "componentTypeNames: [\"ClientEditor\"]"
      ))
    #expect(
      serverLauncher.contains(
        "componentTypeNames: [\"ClientInspector\", \"ClientTile\"]"
      ))
    #expect(
      serverLauncher.contains(
        "componentTypeNames: [\"ClientChart\"]"
      ))
    #expect(serverLauncher.contains("assetPath: \"/assets/sample-app-visible-wasm-runtime.wasm\""))
    #expect(
      serverLauncher.contains("assetPath: \"/assets/sample-app-interaction-wasm-runtime.wasm\""))
    #expect(serverLauncher.contains("assetPath: \"/assets/sample-app-manual-wasm-runtime.wasm\""))
    #expect(serverLauncher.contains("artifactName: \"sample-app-visible-wasm-runtime\""))
    #expect(serverLauncher.contains("artifactName: \"sample-app-interaction-wasm-runtime\""))
    #expect(serverLauncher.contains("artifactName: \"sample-app-manual-wasm-runtime\""))

    let visibleEntrypoint = try String(
      contentsOf: generatedPackage.wasmPackageDirectory
        .appendingPathComponent(
          "Sources/SampleAppVisibleWasmRuntime/SampleAppVisibleWasmRuntime.swift"
        ),
      encoding: .utf8
    )
    let interactionEntrypoint = try String(
      contentsOf: generatedPackage.wasmPackageDirectory
        .appendingPathComponent(
          "Sources/SampleAppInteractionWasmRuntime/SampleAppInteractionWasmRuntime.swift"
        ),
      encoding: .utf8
    )
    let manualEntrypoint = try String(
      contentsOf: generatedPackage.wasmPackageDirectory
        .appendingPathComponent(
          "Sources/SampleAppManualWasmRuntime/SampleAppManualWasmRuntime.swift"
        ),
      encoding: .utf8
    )
    #expect(visibleEntrypoint.contains("ClientChart.self"))
    #expect(visibleEntrypoint.contains("ClientTile.self"))
    #expect(!visibleEntrypoint.contains("ClientEditor.self"))
    #expect(interactionEntrypoint.contains("ClientEditor.self"))
    #expect(!interactionEntrypoint.contains("ClientChart.self"))
    #expect(manualEntrypoint.contains("ClientInspector.self"))
    #expect(manualEntrypoint.contains("ClientTile.self"))
    #expect(!manualEntrypoint.contains("ClientShell.self"))
  }

  @Test
  func repeatedMaterializationPreservesUnchangedGeneratedFiles() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebGeneratedPackageIncrementalTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let swiftWebPackage = root.appendingPathComponent("swift-web", isDirectory: true)
    let swiftHTMLPackage = root.appendingPathComponent("swift-html", isDirectory: true)
    let appPackage = root.appendingPathComponent("SampleApp", isDirectory: true)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-html",
          products: [
              .library(name: "SwiftHTML", targets: ["SwiftHTML"]),
          ],
          targets: [
              .target(name: "SwiftHTML"),
          ]
      )
      """,
      to: swiftHTMLPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftHTMLRuntimeSources(in: swiftHTMLPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "swift-web",
          products: [
              .library(name: "SwiftWebActors", targets: ["SwiftWebActors"]),
              .library(name: "SwiftWebStyle", targets: ["SwiftWebStyle"]),
              .library(name: "SwiftWebUI", targets: ["SwiftWebUI"]),
              .library(name: "SwiftWebUIRuntime", targets: ["SwiftWebUIRuntime"]),
              .library(name: "SwiftWebCore", targets: ["SwiftWebCore"]),
              .library(name: "SwiftWeb", targets: ["SwiftWeb"]),
              .library(name: "SwiftWebHTTPServerHost", targets: ["SwiftWebHTTPServerHost"]),
          ],
          dependencies: [
              .package(path: "\(swiftHTMLPackage.path)"),
          ],
          targets: [
              .target(name: "SwiftWebActors"),
              .target(name: "SwiftWebStyle"),
              .target(name: "SwiftWebUI"),
              .target(name: "SwiftWebUIRuntime"),
              .target(name: "SwiftWebCore"),
              .target(name: "SwiftWeb"),
              .target(name: "SwiftWebHTTPServerHost"),
          ]
      )
      """,
      to: swiftWebPackage.appendingPathComponent("Package.swift")
    )
    try writeSwiftWebStyleRuntimeSources(in: swiftWebPackage)
    try writeSwiftWebUIThemeRuntimeSources(in: swiftWebPackage)
    try write(
      "import SwiftHTML\npublic struct Text {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Components/Text.swift")
    )
    try write(
      "public struct LegacyWebActorSystem {}",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebRuntime/Actors/LegacyWebActorSystem.swift")
    )
    try write(
      "import SwiftHTML\npublic struct RuntimeEntrypoint {}",
      to: swiftWebPackage.appendingPathComponent(
        "Sources/SwiftWebBrowser/ClientRuntime/RuntimeEntrypoint.swift")
    )
    try writeJavaScriptKitRuntimeCheckout(in: swiftWebPackage)
    try write(
      """
      // swift-tools-version: 6.4
      import PackageDescription

      let package = Package(
          name: "SampleApp",
          products: [
              .library(name: "SampleApp", targets: ["SampleApp"]),
          ],
          dependencies: [
              .package(path: "\(swiftWebPackage.path)"),
          ],
          targets: [
              .target(name: "SampleApp"),
          ]
      )
      """,
      to: appPackage.appendingPathComponent("Package.swift")
    )
    try write(
      "public struct SampleApp {}",
      to: appPackage.appendingPathComponent("Sources/SampleApp/App.swift"))
    try write(
      "public struct ClientSample: ClientComponent { public init() {} }",
      to: appPackage.appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    )

    let materializer = SwiftWebGeneratedPackageMaterializer(appPackageDirectory: appPackage)
    let generatedPackage = try materializer.materialize()
    let packageSwift = generatedPackage.wasmPackageDirectory.appendingPathComponent("Package.swift")
    let wasmEntrypoint = generatedPackage.wasmPackageDirectory
      .appendingPathComponent("Sources/SampleAppWasmRuntime/SampleAppWasmRuntime.swift")
    let copiedClientSource = generatedPackage.wasmPackageDirectory
      .appendingPathComponent("Sources/SampleApp/ClientSample.swift")
    let initialPackageDate = try #require(
      packageSwift.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let initialEntrypointDate = try #require(
      wasmEntrypoint.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let initialCopiedSourceDate = try #require(
      copiedClientSource.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate)

    Thread.sleep(forTimeInterval: 1.1)
    _ = try materializer.materialize()

    let nextPackageDate = try #require(
      packageSwift.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let nextEntrypointDate = try #require(
      wasmEntrypoint.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
    let nextCopiedSourceDate = try #require(
      copiedClientSource.resourceValues(forKeys: [.contentModificationDateKey])
        .contentModificationDate)

    #expect(nextPackageDate == initialPackageDate)
    #expect(nextEntrypointDate == initialEntrypointDate)
    #expect(nextCopiedSourceDate == initialCopiedSourceDate)
  }

  private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
      at: url.deletingLastPathComponent(),
      withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
  }

  private func wasmEnvironment(
    embedded: Bool,
    availableModules: Set<String>
  ) throws -> ActorGenerationTargetEnvironment {
    try ActorGenerationTargetEnvironment(
      availableModules: availableModules,
      features: embedded ? ["ApproachableConcurrency", "Embedded"] : [
        "ApproachableConcurrency"
      ],
      operatingSystem: "WASI",
      architecture: "wasm32",
      objectFormat: "wasm",
      pointerBitWidth: 32,
      atomicBitWidths: [8, 16, 32, 64],
      languageVersion: [6],
      compilerVersion: [6, 4]
    )
  }

  private func writeJavaScriptKitRuntimeCheckout(in swiftWebPackage: URL) throws {
    let sourceRoot =
      swiftWebPackage
      .appendingPathComponent(".build/checkouts/JavaScriptKit/Sources", isDirectory: true)
    try write(
      "public final class JSObject {}",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/FundamentalObjects/JSObject.swift")
    )
    try write(
      "public macro JS() = #externalMacro(module: \"BridgeJSMacros\", type: \"JSMacro\")",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/Macros.swift")
    )
    try write(
      "runtime",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/Runtime/runtime.mjs")
    )
    try write(
      "# Documentation",
      to: sourceRoot.appendingPathComponent("JavaScriptKit/Documentation.docc/Documentation.md")
    )
    try write(
      "#pragma once",
      to: sourceRoot.appendingPathComponent("_CJavaScriptKit/include/_CJavaScriptKit.h")
    )
  }

  private func writeSwiftHTMLRuntimeSources(in swiftHTMLPackage: URL) throws {
    let sourceRoot = swiftHTMLPackage.appendingPathComponent("Sources/SwiftHTML", isDirectory: true)
    try write(
      "public protocol HTML: Sendable {}",
      to: sourceRoot.appendingPathComponent("Core/HTML.swift")
    )
    try write(
      "public struct HTMLRenderer {}",
      to: sourceRoot.appendingPathComponent("Rendering/HTMLRenderer.swift")
    )
    try write(
      "# Documentation",
      to: sourceRoot.appendingPathComponent("SwiftHTML.docc/SwiftHTML.md")
    )
    try write(
      "public macro Preview() = #externalMacro(module: \"SwiftHTMLMacros\", type: \"HTMLPreviewMacro\")",
      to: sourceRoot.appendingPathComponent("Preview/HTMLPreviewMacro.swift")
    )
  }

  private func writeSwiftWebStyleRuntimeSources(in swiftWebPackage: URL) throws {
    for targetName in [
      "SwiftWebActors",
      "SwiftWebStyle",
      "SwiftWebUIRuntime",
      "SwiftWebCore",
      "SwiftWeb",
      "SwiftWebHTTPServerHost",
    ] {
      try write(
        "public enum \(targetName)FixtureModule {}",
        to: swiftWebPackage.appendingPathComponent(
          "Sources/\(targetName)/Fixture.swift"
        )
      )
    }
    try write(
      "import SwiftHTML\npublic struct StyleRegistry { public init() {} }",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Style/StyleRegistry.swift")
    )
  }

  private func writeSwiftWebUIThemeRuntimeSources(in swiftWebPackage: URL) throws {
    try write(
      "import SwiftHTML\nimport SwiftWebStyle\npublic struct ThemeToken { public init() {} }",
      to: swiftWebPackage.appendingPathComponent("Sources/SwiftWebUI/Theme/ThemeToken.swift")
    )
  }

  private func writeSwiftHTMLClientRuntimeSources(in swiftHTMLPackage: URL) throws {
    let sourceRoot = swiftHTMLPackage.appendingPathComponent(
      "Sources/SwiftHTMLClientRuntime",
      isDirectory: true
    )
    try write(
      "public protocol ClientDOMHost {}",
      to: sourceRoot.appendingPathComponent("ClientDOMHost.swift")
    )
    try write(
      "public struct ClientHTMLDocument {}",
      to: sourceRoot.appendingPathComponent("ClientHTMLDocument.swift")
    )
  }
}

private struct GeneratedPackageCommitFixtureError: Error {}
