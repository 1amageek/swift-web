import AsyncHTTPClient
import Foundation
import HTTPTypes
import Logging
import NIOCore
import NIOHTTP1
import NIOPosix
import ServiceContextModule
import SwiftHTML
import Synchronization
import Testing

@testable import SwiftWebDevelopment
@testable import SwiftWebDevelopmentHooks

@Suite
struct SwiftWebDevHMRTests {
  @Test
  func wasmScratchDirectoryIsSiblingOfServerScratchDirectory() {
    let root = URL(fileURLWithPath: "/tmp/swiftweb-generated", isDirectory: true)
    let serverScratch = root
      .appendingPathComponent(".build", isDirectory: true)
      .appendingPathComponent("server", isDirectory: true)

    let wasmScratch = SwiftWebDevWasmScratchDirectory.resolve(from: serverScratch)

    #expect(wasmScratch?.path == "/tmp/swiftweb-generated/wasm-build/server")
    #expect(!(wasmScratch?.path.hasPrefix(serverScratch.path + "/") ?? true))
    #expect(!(wasmScratch?.path.hasPrefix("/tmp/swiftweb-generated/.build/") ?? true))
  }

  @Test
  func changeClassifierSeparatesStyleClientAndServerChanges() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHMRTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb dev host live test cleanup failed: \(String(describing: error))")
      }
    }

    let clientFile = root.appendingPathComponent("Sources/App/ClientCounter.swift")
    let cssFile = root.appendingPathComponent("Sources/App/App.css")
    let packageFile = root.appendingPathComponent("Package.swift")
    try write("public struct ClientCounter: ClientComponent {}", to: clientFile)
    try write(".counter { color: red; }", to: cssFile)
    try write("// package", to: packageFile)

    let generated = SwiftWebGeneratedPackage(
      appPackageDirectory: root,
      packageDirectory: root.appendingPathComponent(".swiftweb/generated", isDirectory: true),
      swiftWebPackageDirectory: root.appendingPathComponent("swift-web", isDirectory: true),
      appProductName: "App",
      serverProductName: "app-server",
      devProductName: "App",
      wasmProductNames: ["counter-wasm-runtime"],
      wasmRuntimes: [
        SwiftWebGeneratedWasmRuntime(
          targetName: "CounterWasmRuntime",
          productName: "counter-wasm-runtime",
          componentTypeName: "ClientCounter",
          assetPath: "/assets/counter-wasm-runtime.wasm"
        )
      ]
    )
    let classifier = SwiftWebDevChangeClassifier(
      appPackageDirectory: root,
      generatedPackage: generated
    )

    let clientPlan = classifier.classify([
      SwiftWebDevFileChange(
        path: "Sources/App/ClientCounter.swift", url: clientFile, kind: .modified)
    ])
    #expect(clientPlan.clientRuntimes.map(\.componentTypeName) == ["ClientCounter"])
    #expect(clientPlan.styleFiles.isEmpty)
    #expect(!clientPlan.requiresServerRestart)

    let stylePlan = classifier.classify([
      SwiftWebDevFileChange(path: "Sources/App/App.css", url: cssFile, kind: .modified)
    ])
    #expect(stylePlan.styleFiles == [cssFile.standardizedFileURL])
    #expect(stylePlan.clientRuntimes.isEmpty)
    #expect(!stylePlan.requiresServerRestart)

    let serverPlan = classifier.classify([
      SwiftWebDevFileChange(path: "Package.swift", url: packageFile, kind: .modified)
    ])
    #expect(serverPlan.requiresServerRestart)
  }

  @Test
  func changeClassifierMapsAnyComponentInABundleToThatRuntime() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevMultiComponentHMRTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let shellFile = root.appendingPathComponent("Sources/App/ClientShell.swift")
    let badgeFile = root.appendingPathComponent("Sources/App/ClientBadge.swift")
    try write("public struct ClientShell: ClientComponent {}", to: shellFile)
    try write("public struct ClientBadge: ClientComponent {}", to: badgeFile)

    let generated = SwiftWebGeneratedPackage(
      appPackageDirectory: root,
      packageDirectory: root.appendingPathComponent(".swiftweb/generated", isDirectory: true),
      swiftWebPackageDirectory: root.appendingPathComponent("swift-web", isDirectory: true),
      appProductName: "App",
      serverProductName: "app-server",
      devProductName: "App",
      wasmProductNames: ["app-wasm-runtime"],
      wasmRuntimes: [
        SwiftWebGeneratedWasmRuntime(
          targetName: "AppWasmRuntime",
          productName: "app-wasm-runtime",
          componentTypeNames: ["ClientShell", "ClientBadge"],
          assetPath: "/assets/app-wasm-runtime.wasm"
        )
      ]
    )
    let classifier = SwiftWebDevChangeClassifier(
      appPackageDirectory: root,
      generatedPackage: generated
    )

    let shellPlan = classifier.classify([
      SwiftWebDevFileChange(path: "Sources/App/ClientShell.swift", url: shellFile, kind: .modified)
    ])
    let badgePlan = classifier.classify([
      SwiftWebDevFileChange(path: "Sources/App/ClientBadge.swift", url: badgeFile, kind: .modified)
    ])

    #expect(shellPlan.clientRuntimes.map(\.productName) == ["app-wasm-runtime"])
    #expect(badgePlan.clientRuntimes.map(\.productName) == ["app-wasm-runtime"])
    #expect(!shellPlan.requiresServerRestart)
    #expect(!badgePlan.requiresServerRestart)
  }

  @Test
  func changeClassifierKeepsClientOnlyChangesOffWorkerRebuildAndMarksMixedPlans() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHMRPlanBoundaryTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb HMR plan boundary test cleanup failed: \(String(describing: error))")
      }
    }

    let clientFile = root.appendingPathComponent("Sources/App/ClientCounter.swift")
    let styleFile = root.appendingPathComponent("Sources/App/Counter.css")
    let serverFile = root.appendingPathComponent("Sources/App/CounterPage.swift")
    try write("public struct ClientCounter: ClientComponent {}", to: clientFile)
    try write(".counter { color: blue; }", to: styleFile)
    try write("public struct CounterPage {}", to: serverFile)

    let generated = SwiftWebGeneratedPackage(
      appPackageDirectory: root,
      packageDirectory: root.appendingPathComponent(".swiftweb/generated", isDirectory: true),
      swiftWebPackageDirectory: root.appendingPathComponent("swift-web", isDirectory: true),
      appProductName: "App",
      serverProductName: "app-server",
      devProductName: "App",
      wasmProductNames: ["counter-wasm-runtime"],
      wasmRuntimes: [
        SwiftWebGeneratedWasmRuntime(
          targetName: "CounterWasmRuntime",
          productName: "counter-wasm-runtime",
          componentTypeName: "ClientCounter",
          assetPath: "/assets/counter-wasm-runtime.wasm"
        )
      ]
    )
    let classifier = SwiftWebDevChangeClassifier(
      appPackageDirectory: root,
      generatedPackage: generated
    )

    let clientOnlyPlan = classifier.classify([
      SwiftWebDevFileChange(
        path: "Sources/App/ClientCounter.swift",
        url: clientFile,
        kind: .modified
      )
    ])
    #expect(clientOnlyPlan.clientRuntimes.map(\.productName) == ["counter-wasm-runtime"])
    #expect(clientOnlyPlan.styleFiles.isEmpty)
    #expect(!clientOnlyPlan.requiresServerRestart)

    let clientAndStylePlan = classifier.classify([
      SwiftWebDevFileChange(
        path: "Sources/App/ClientCounter.swift",
        url: clientFile,
        kind: .modified
      ),
      SwiftWebDevFileChange(path: "Sources/App/Counter.css", url: styleFile, kind: .modified),
    ])
    #expect(clientAndStylePlan.clientRuntimes.map(\.productName) == ["counter-wasm-runtime"])
    #expect(clientAndStylePlan.styleFiles == [styleFile.standardizedFileURL])
    #expect(!clientAndStylePlan.requiresServerRestart)

    let serverOnlyPlan = classifier.classify([
      SwiftWebDevFileChange(path: "Sources/App/CounterPage.swift", url: serverFile, kind: .modified)
    ])
    #expect(serverOnlyPlan.clientRuntimes.isEmpty)
    #expect(serverOnlyPlan.styleFiles.isEmpty)
    #expect(serverOnlyPlan.requiresServerRestart)
    #expect(serverOnlyPlan.serverRestartReasons == ["Sources/App/CounterPage.swift"])

    let mixedPlan = classifier.classify([
      SwiftWebDevFileChange(
        path: "Sources/App/ClientCounter.swift",
        url: clientFile,
        kind: .modified
      ),
      SwiftWebDevFileChange(path: "Sources/App/CounterPage.swift", url: serverFile, kind: .modified),
    ])
    #expect(mixedPlan.clientRuntimes.map(\.productName) == ["counter-wasm-runtime"])
    #expect(mixedPlan.requiresServerRestart)
    #expect(mixedPlan.serverRestartReasons == ["Sources/App/CounterPage.swift"])
  }

  @Test
  func changeClassifierTreatsMixedClientAndServerFileAsClientAndWorkerRebuild() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevMixedClientServerFileTests-\(UUID().uuidString)",
        isDirectory: true
      )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb mixed HMR file test cleanup failed: \(String(describing: error))")
      }
    }

    let mixedFile = root.appendingPathComponent("Sources/App/CounterFeature.swift")
    try write(
      """
      @Page("/counter")
      public struct CounterPage {}

      public struct ClientCounter: ClientComponent {}
      """,
      to: mixedFile
    )

    let generated = SwiftWebGeneratedPackage(
      appPackageDirectory: root,
      packageDirectory: root.appendingPathComponent(".swiftweb/generated", isDirectory: true),
      swiftWebPackageDirectory: root.appendingPathComponent("swift-web", isDirectory: true),
      appProductName: "App",
      serverProductName: "app-server",
      devProductName: "App",
      wasmProductNames: ["counter-wasm-runtime"],
      wasmRuntimes: [
        SwiftWebGeneratedWasmRuntime(
          targetName: "CounterWasmRuntime",
          productName: "counter-wasm-runtime",
          componentTypeName: "ClientCounter",
          assetPath: "/assets/counter-wasm-runtime.wasm"
        )
      ]
    )
    let classifier = SwiftWebDevChangeClassifier(
      appPackageDirectory: root,
      generatedPackage: generated
    )

    let plan = classifier.classify([
      SwiftWebDevFileChange(
        path: "Sources/App/CounterFeature.swift",
        url: mixedFile,
        kind: .modified
      )
    ])

    #expect(plan.clientRuntimes.map(\.productName) == ["counter-wasm-runtime"])
    #expect(plan.requiresServerRestart)
    #expect(plan.serverRestartReasons == ["Sources/App/CounterFeature.swift"])
  }

  @Test
  func swiftFileClassifierUsesSyntaxAndIgnoresCommentMarkers() {
    let classification = SwiftWebDevSwiftFileClassifier.classify(
      source: """
      // @Page("/counter")
      public struct ClientCounter: ClientComponent {}
      """
    )

    #expect(classification.clientComponentTypeNames == ["ClientCounter"])
    #expect(!classification.hasServerRuntimeSurface)
  }

  @Test
  func fileChangeCoalescerMergesDuplicatePathEvents() {
    let url = URL(fileURLWithPath: "/tmp/Counter.swift")
    let recreated = SwiftWebDevFileChangeCoalescer.coalesce([
      SwiftWebDevFileChange(path: "Sources/App/Counter.swift", url: url, kind: .removed),
      SwiftWebDevFileChange(path: "Sources/App/Counter.swift", url: url, kind: .added),
    ])
    let addedThenModified = SwiftWebDevFileChangeCoalescer.coalesce([
      SwiftWebDevFileChange(path: "Sources/App/ClientCounter.swift", url: url, kind: .added),
      SwiftWebDevFileChange(path: "Sources/App/ClientCounter.swift", url: url, kind: .modified),
    ])

    #expect(recreated.map(\.kind) == [.modified])
    #expect(addedThenModified.map(\.kind) == [.added])
  }

  @Test(.timeLimit(.minutes(1)))
  func fileChangeWatcherCoalescesFallbackChangesAcrossQuietWindow() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebFileWatcherCoalescingTests-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb watcher coalescing test cleanup failed: \(String(describing: error))")
      }
    }

    let first = root.appendingPathComponent("Sources/App/ClientCounter.swift")
    let second = root.appendingPathComponent("Sources/App/Counter.css")
    let watcher = SwiftWebDevFileChangeWatcher(
      roots: [root],
      coalescingInterval: 0.08,
      usesFileEvents: false
    )
    try write("public struct ClientCounter: ClientComponent {}", to: first)
    let writer = Task {
      try await Task.sleep(nanoseconds: 30_000_000)
      try write(".counter { color: green; }", to: second)
    }

    let changes = watcher.waitForChangeSet(timeout: 0)
    try await writer.value

    #expect(Set(changes.map(\.path)) == [
      "Sources/App/ClientCounter.swift",
      "Sources/App/Counter.css",
    ])
  }

  @Test
  func wasmBuildInputHashChangesOnlyForBuildInputs() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebWasmBuildInputHasherTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    try write("// package", to: root.appendingPathComponent("Package.swift"))
    try write(
      "public struct ClientCounter: ClientComponent {}",
      to: root.appendingPathComponent("Sources/App/ClientCounter.swift")
    )
    try write("not a build input", to: root.appendingPathComponent("README.md"))
    let runtime = SwiftWebGeneratedWasmRuntime(
      packageDirectory: root,
      targetName: "AppWasmRuntime",
      productName: "app-wasm-runtime",
      componentTypeNames: ["ClientCounter"],
      assetPath: "/assets/app-wasm-runtime.wasm"
    )

    let firstHash = try SwiftWebWasmBuildInputHasher.hash(
      runtime: runtime,
      sdkName: "swift-6.3.1-RELEASE_wasm",
      swiftExecutablePath: "/usr/bin/swift"
    )
    let secondHash = try SwiftWebWasmBuildInputHasher.hash(
      runtime: runtime,
      sdkName: "swift-6.3.1-RELEASE_wasm",
      swiftExecutablePath: "/usr/bin/swift"
    )
    try write("changed but ignored", to: root.appendingPathComponent("README.md"))
    let afterIgnoredFileHash = try SwiftWebWasmBuildInputHasher.hash(
      runtime: runtime,
      sdkName: "swift-6.3.1-RELEASE_wasm",
      swiftExecutablePath: "/usr/bin/swift"
    )
    try write(
      "public struct ClientCounter: ClientComponent { public init() {} }",
      to: root.appendingPathComponent("Sources/App/ClientCounter.swift")
    )
    let afterSourceChangeHash = try SwiftWebWasmBuildInputHasher.hash(
      runtime: runtime,
      sdkName: "swift-6.3.1-RELEASE_wasm",
      swiftExecutablePath: "/usr/bin/swift"
    )

    #expect(firstHash == secondHash)
    #expect(firstHash == afterIgnoredFileHash)
    #expect(firstHash != afterSourceChangeHash)
  }

  @Test
  func eventLogStoresTypedEventsInOrder() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevEventLogTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let log = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try log.reset()
    let connected = SwiftWebDevEvent(kind: .connected)
    let style = SwiftWebDevEvent(
      kind: .stylePatch,
      stylePatch: SwiftWebDevStylePatch(css: ".counter { color: blue; }")
    )
    let clientBuild = SwiftWebDevEvent(kind: .clientBuildStarted, message: "building client")
    try log.append(connected)
    try log.append(style)
    try log.append(clientBuild)

    #expect(
      try log.events(after: nil).map(\.kind) == [.connected, .stylePatch, .clientBuildStarted])
    #expect(try log.events(after: connected.id).map(\.kind) == [.stylePatch, .clientBuildStarted])
  }

  @Test
  func clientManifestSnapshotStoreReturnsRuntimeSchemaHashes() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevManifestSnapshotTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let bundleID = ClientBundleID("counter-runtime")
    let store = SwiftWebDevClientManifestSnapshotStore(
      fileURL: root.appendingPathComponent("client-manifest-snapshot.json")
    )
    try store.write(
      ClientBundleManifest(
        runtimeBundleID: bundleID,
        components: [
          ClientComponentAsset(
            componentID: ComponentID("counter"),
            typeName: "Demo.ClientCounter",
            bundleID: bundleID,
            loadPolicy: .eager,
            entrySymbols: [ClientSymbolID("ClientCounter")],
            stateSchemaHash: "state-schema",
            environmentSchemaHash: "environment-schema"
          )
        ]
      ))

    let hashes = try store.schemaHashes(
      for: SwiftWebGeneratedWasmRuntime(
        targetName: "CounterWasmRuntime",
        productName: "counter-wasm-runtime",
        componentTypeNames: ["ClientCounter"],
        bundleID: bundleID,
        assetPath: "/assets/counter-wasm-runtime.wasm"
      ))

    #expect(hashes.stateSchemaHash == "state-schema")
    #expect(hashes.environmentSchemaHash == "environment-schema")
  }

  @Test
  func clientManifestSnapshotStoreRecordsWriteFailuresAsDevErrors() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevManifestSnapshotErrorTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let blockedParent = root.appendingPathComponent("blocked-parent")
    try write("not a directory", to: blockedParent)
    let log = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try log.reset()
    let store = SwiftWebDevClientManifestSnapshotStore(
      fileURL: blockedParent.appendingPathComponent("client-manifest-snapshot.json")
    )

    store.record(
      ClientBundleManifest(runtimeBundleID: ClientBundleID("counter-runtime")),
      eventLog: log
    )

    let events = try log.events(after: nil)
    #expect(events.map(\.kind) == [.error])
    #expect(events.first?.message?.contains("SwiftWeb dev manifest snapshot write failed") == true)
  }

  @Test
  func devEventPayloadReturnsConnectedForInitialConnection() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevInitialEventPayloadTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let log = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try log.reset()

    let payload = try await SwiftWebDevHotReload.eventPayload(from: log, after: nil)

    #expect(payload.contains("event: connected"))
    #expect(payload.contains(#""kind":"connected""#))
  }

  @Test
  func devEventPayloadReturnsEventsAfterLastEventID() async throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevIncrementalEventPayloadTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let log = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try log.reset()
    let oldEvent = SwiftWebDevEvent(
      kind: .stylePatch, stylePatch: SwiftWebDevStylePatch(css: ".old {}"))
    let nextEvent = SwiftWebDevEvent(kind: .clientBuildStarted, message: "client building")
    try log.append(oldEvent)
    try log.append(nextEvent)

    let payload = try await SwiftWebDevHotReload.eventPayload(from: log, after: oldEvent.id)

    #expect(!payload.contains(oldEvent.id))
    #expect(payload.contains(nextEvent.id))
    #expect(payload.contains("event: clientBuildStarted"))
  }

  @Test
  func initialWasmBuildFailureIsFatalAndActionable() {
    let error = SwiftWebDevRuntimeError.initialWasmBuildFailed(
      component: "Demo.StoryboardCatalog",
      product: "storyboard-preview-wasm-runtime",
      reason: "missing SDK"
    )

    #expect(error.exitCode == 70)
    #expect(error.description.contains("Initial Client WASM build failed"))
    #expect(error.description.contains("Demo.StoryboardCatalog"))
    #expect(error.description.contains("storyboard-preview-wasm-runtime"))
    #expect(error.description.contains("non-interactive"))
    #expect(error.description.contains("missing SDK"))
  }

  @Test
  func boundaryAnnotatorAddsDevMetadataToClientComponentRootElement() {
    let componentID = ComponentID("component-1")
    let nestedComponentID = ComponentID("nested")
    let html = """
      <main><!--component:component-1:begin--><!--component:nested:begin--><div data-node="3">Counter</div><!--component:nested:end--><!--component:component-1:end--></main>
      """
    let manifest = ClientBundleManifest(
      runtimeBundleID: ClientBundleID("runtime"),
      bundles: [],
      components: [
        ClientComponentAsset(
          componentID: componentID,
          typeName: "Demo.Counter",
          bundleID: ClientBundleID("counter-runtime"),
          loadPolicy: .eager,
          entrySymbols: [ClientSymbolID("Demo.Counter")]
        ),
        ClientComponentAsset(
          componentID: nestedComponentID,
          typeName: "Demo.Counter.Label",
          bundleID: ClientBundleID("counter-runtime"),
          loadPolicy: .eager,
          entrySymbols: [ClientSymbolID("Demo.Counter.Label")]
        ),
      ]
    )
    let index = BrowserHydrationIndex(
      rootID: HTMLNodeID(1),
      nodes: [
        BrowserHydrationNodeRecord(
          id: HTMLNodeID(1),
          parentID: nil,
          childIDs: [HTMLNodeID(2)],
          role: .component,
          componentID: componentID,
          fingerprint: NodeFingerprint(1)
        ),
        BrowserHydrationNodeRecord(
          id: HTMLNodeID(2),
          parentID: HTMLNodeID(1),
          childIDs: [HTMLNodeID(3)],
          role: .component,
          componentID: nestedComponentID,
          fingerprint: NodeFingerprint(2)
        ),
        BrowserHydrationNodeRecord(
          id: HTMLNodeID(3),
          parentID: HTMLNodeID(2),
          childIDs: [],
          role: .element,
          name: "div",
          fingerprint: NodeFingerprint(3)
        ),
      ],
      components: [
        BrowserHydrationComponentRecord(
          id: componentID,
          typeName: "Demo.Counter",
          path: "document:0",
          nodeID: HTMLNodeID(1),
          bundleID: ClientBundleID("counter-runtime"),
          loadPolicy: .eager,
          serverSlotIDs: []
        ),
        BrowserHydrationComponentRecord(
          id: nestedComponentID,
          typeName: "Demo.Counter.Label",
          path: "document:0/child:0",
          nodeID: HTMLNodeID(2),
          bundleID: ClientBundleID("counter-runtime"),
          loadPolicy: .eager,
          serverSlotIDs: []
        ),
      ],
      serverSlots: [],
      handlers: []
    )

    let annotated = SwiftWebDevBoundaryAnnotator.annotate(
      html,
      manifest: manifest,
      hydrationIndex: index,
      isEnabled: true
    )

    #expect(annotated.contains(#"data-component="component-1""#))
    #expect(annotated.contains(#"data-hmr-boundary="true""#))
    #expect(annotated.contains(#"data-state-schema=""#))
    #expect(annotated.contains(#"data-component-type="Demo.Counter""#))
    #expect(annotated.contains(#"data-bundle="counter-runtime""#))
    #expect(!annotated.contains(#"data-component="nested""#))
  }

  @Test
  func boundaryAnnotatorPrefersOuterSplitBoundaryWhenManifestListsInnerComponentFirst() {
    let componentID = ComponentID("manual-counter")
    let nestedComponentID = ComponentID("manual-group-box")
    let runtimeBundleID = ClientBundleID("main-runtime")
    let html = """
      <main><!--component:manual-counter:begin--><!--component:manual-group-box:begin--><div data-node="3" data-component="manual-group-box">Manual</div><!--component:manual-group-box:end--><!--component:manual-counter:end--></main>
      """
    let manifest = ClientBundleManifest(
      runtimeBundleID: runtimeBundleID,
      bundles: [],
      components: [
        ClientComponentAsset(
          componentID: nestedComponentID,
          typeName: "SwiftWebUI.GroupBox",
          bundleID: runtimeBundleID,
          loadPolicy: .manual,
          entrySymbols: [ClientSymbolID("SwiftWebUI.GroupBox")]
        ),
        ClientComponentAsset(
          componentID: componentID,
          typeName: "Demo.ClientManualCounter",
          bundleID: ClientBundleID("component-manual"),
          loadPolicy: .manual,
          entrySymbols: [ClientSymbolID("Demo.ClientManualCounter")]
        ),
      ]
    )
    let index = BrowserHydrationIndex(
      rootID: HTMLNodeID(1),
      nodes: [
        BrowserHydrationNodeRecord(
          id: HTMLNodeID(1),
          parentID: nil,
          childIDs: [HTMLNodeID(2)],
          role: .component,
          componentID: componentID,
          fingerprint: NodeFingerprint(1)
        ),
        BrowserHydrationNodeRecord(
          id: HTMLNodeID(2),
          parentID: HTMLNodeID(1),
          childIDs: [HTMLNodeID(3)],
          role: .component,
          componentID: nestedComponentID,
          fingerprint: NodeFingerprint(2)
        ),
        BrowserHydrationNodeRecord(
          id: HTMLNodeID(3),
          parentID: HTMLNodeID(2),
          childIDs: [],
          role: .element,
          name: "div",
          fingerprint: NodeFingerprint(3)
        ),
      ],
      components: [
        BrowserHydrationComponentRecord(
          id: nestedComponentID,
          typeName: "SwiftWebUI.GroupBox",
          path: "document:0/child:0",
          nodeID: HTMLNodeID(2),
          bundleID: runtimeBundleID,
          loadPolicy: .manual,
          serverSlotIDs: []
        ),
        BrowserHydrationComponentRecord(
          id: componentID,
          typeName: "Demo.ClientManualCounter",
          path: "document:0",
          nodeID: HTMLNodeID(1),
          bundleID: ClientBundleID("component-manual"),
          loadPolicy: .manual,
          serverSlotIDs: []
        ),
      ],
      serverSlots: [],
      handlers: []
    )

    let annotated = SwiftWebDevBoundaryAnnotator.annotate(
      html,
      manifest: manifest,
      hydrationIndex: index,
      isEnabled: true
    )

    #expect(annotated.contains(#"data-component="manual-counter""#))
    #expect(annotated.contains(#"data-component-type="Demo.ClientManualCounter""#))
    #expect(annotated.contains(#"data-bundle="component-manual""#))
    #expect(!annotated.contains(#"data-component="manual-group-box""#))
    #expect(!annotated.contains(#"data-component-type="SwiftWebUI.GroupBox""#))
  }

  @Test
  func workerRegistryKeepsActiveTargetDuringBuildAndError() {
    let registry = SwiftWebDevWorkerRegistry()
    let target = SwiftWebDevWorkerTarget(host: "127.0.0.1", port: 12345)

    registry.activate(target)
    registry.markBuilding(message: "building", detail: "changed.swift")
    #expect(registry.activeTarget() == target)
    #expect(registry.status().activeWorkerURL == target.url)
    #expect(registry.status().phase == "building")

    registry.markError(message: "failed", detail: "compiler error")
    #expect(registry.activeTarget() == target)
    #expect(registry.status().activeWorkerURL == target.url)
    #expect(registry.status().phase == "error")
  }

  @Test
  func devContextCarrierRoundTripsRequestWorkerAndPhase() {
    let target = SwiftWebDevWorkerTarget(host: "127.0.0.1", port: 12345)
    let status = SwiftWebDevHostStatus(
      phase: "ready",
      message: "ready",
      activeWorkerURL: target.url
    )
    var context = ServiceContext.topLevel
    var headers: HTTPFields = [:]

    SwiftWebDevContextCarrier.enrich(
      &context,
      requestID: "request-1",
      workerURL: target.url,
      phase: status.phase
    )
    SwiftWebDevContextCarrier.inject(context, into: &headers)

    let restored = SwiftWebDevContextCarrier.extract(from: headers)
    #expect(restored.swiftWebDevRequestID == "request-1")
    #expect(restored.swiftWebDevWorkerURL == target.url)
    #expect(restored.swiftWebDevPhase == "ready")
  }

  @Test
  func portAllocatorReturnsFreeLoopbackPort() throws {
    let port = try SwiftWebDevPortAllocator.allocateLoopbackPort()

    #expect(port > 0)
    #expect(!SwiftWebDevPortProbe.isListening(host: "127.0.0.1", port: port))
  }

  @Test
  func expectedTerminationClassifierRecognizesDevShutdownErrors() {
    #expect(SwiftWebDevExpectedTermination.isExpected(CancellationError()))
    #expect(SwiftWebDevExpectedTermination.isExpected(ChannelError.ioOnClosedChannel))
    #expect(SwiftWebDevExpectedTermination.isExpected(ChannelError.eof))
    #expect(SwiftWebDevExpectedTermination.isExpected(HTTPParserError.invalidEOFState))
    #expect(SwiftWebDevExpectedTermination.isExpected(HTTPParserError.closedConnection))
    #expect(SwiftWebDevExpectedTermination.isExpected(HTTPClientError.cancelled))
    #expect(SwiftWebDevExpectedTermination.isExpected(HTTPClientError.remoteConnectionClosed))
    #expect(SwiftWebDevExpectedTermination.isExpected(HTTPClientError.requestStreamCancelled))
    #expect(!SwiftWebDevExpectedTermination.isExpected(HTTPClientError.readTimeout))
  }

  @Test
  func wasmArtifactCacheRestoresArtifactsAndPrunesLeastRecentlyUsedEntries() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebWasmArtifactCacheTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb WASM artifact cache test cleanup failed: \(String(describing: error))")
      }
    }

    let sourceDirectory = root.appendingPathComponent("sources", isDirectory: true)
    let restoreDirectory = root.appendingPathComponent("restored", isDirectory: true)
    let cache = SwiftWebDevWasmArtifactCache(
      rootDirectory: root.appendingPathComponent("cache", isDirectory: true),
      environment: ["SWIFTWEB_WASM_ARTIFACT_CACHE_MAX_BYTES": "20"]
    )

    let firstArtifact = sourceDirectory.appendingPathComponent("first.wasm")
    let secondArtifact = sourceDirectory.appendingPathComponent("second.wasm")
    let thirdArtifact = sourceDirectory.appendingPathComponent("third.wasm")
    try write("first-aaa", to: firstArtifact)
    try write("second-b", to: secondArtifact)
    try write("third-cc", to: thirdArtifact)

    try cache.store(inputHash: "input-a", artifactURL: firstArtifact, artifactHash: "hash-a")
    Thread.sleep(forTimeInterval: 0.02)
    try cache.store(inputHash: "input-b", artifactURL: secondArtifact, artifactHash: "hash-b")
    Thread.sleep(forTimeInterval: 0.02)

    let restoredFirst = restoreDirectory.appendingPathComponent("first.wasm")
    #expect(try cache.restore(inputHash: "input-a", to: restoredFirst) == "hash-a")
    #expect(try String(contentsOf: restoredFirst, encoding: .utf8) == "first-aaa")
    Thread.sleep(forTimeInterval: 0.02)

    try cache.store(inputHash: "input-c", artifactURL: thirdArtifact, artifactHash: "hash-c")

    #expect(try cache.restore(inputHash: "input-b", to: restoreDirectory.appendingPathComponent("second.wasm")) == nil)
    #expect(try cache.restore(inputHash: "input-a", to: restoreDirectory.appendingPathComponent("first-again.wasm")) == "hash-a")
    #expect(try cache.restore(inputHash: "input-c", to: restoreDirectory.appendingPathComponent("third.wasm")) == "hash-c")
  }

  @Test(.timeLimit(.minutes(1)))
  func devHostServesStatusAndProxiesToActiveWorker() async throws {
    let publicPort = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHostLiveTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let worker = try SwiftWebDevTestWorker.start(responseBody: "worker-ok")
    defer {
      do {
        try worker.stop()
      } catch {
        Issue.record("SwiftWeb dev test worker shutdown failed: \(String(describing: error))")
      }
    }

    let eventLog = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try eventLog.reset()
    let registry = SwiftWebDevWorkerRegistry()
    let host = SwiftWebDevHost(
      configuration: SwiftWebDevRuntimeConfiguration(
        packageDirectory: root,
        host: "127.0.0.1",
        port: publicPort,
        readinessTimeout: 2
      ),
      devToken: "test-token",
      eventLog: eventLog,
      workerRegistry: registry,
      logger: Logger(label: "codes.swiftweb.tests.dev-host")
    )
    try await host.start()
    do {
      registry.activate(worker.target)

      let statusData = try await fetch("http://127.0.0.1:\(publicPort)/__dev/status")
      let status = try JSONDecoder.swiftWebDevEvent.decode(SwiftWebDevHostStatus.self, from: statusData)
      #expect(status.phase == "ready")
      #expect(status.activeWorkerURL == worker.target.url)

      let proxied = try await fetch("http://127.0.0.1:\(publicPort)/hello")
      #expect(String(decoding: proxied, as: UTF8.self) == "worker-ok")
    } catch {
      await host.stop()
      throw error
    }

    await host.stop()
    #expect(!SwiftWebDevPortProbe.isListening(host: "127.0.0.1", port: publicPort))
  }

  @Test(.timeLimit(.minutes(1)))
  func devHostForwardsPublicOriginWhenProxyingToWorker() async throws {
    let publicPort = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHostHostHeaderTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let worker = try SwiftWebDevTestWorker.startEchoingHeader("X-Forwarded-Host")
    defer {
      do {
        try worker.stop()
      } catch {
        Issue.record("SwiftWeb dev test worker shutdown failed: \(String(describing: error))")
      }
    }

    let eventLog = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try eventLog.reset()
    let registry = SwiftWebDevWorkerRegistry()
    let host = SwiftWebDevHost(
      configuration: SwiftWebDevRuntimeConfiguration(
        packageDirectory: root,
        host: "127.0.0.1",
        port: publicPort,
        readinessTimeout: 2
      ),
      devToken: "test-token",
      eventLog: eventLog,
      workerRegistry: registry,
      logger: Logger(label: "codes.swiftweb.tests.dev-host")
    )
    try await host.start()
    do {
      registry.activate(worker.target)

      let proxied = try await fetch("http://127.0.0.1:\(publicPort)/host")
      #expect(String(decoding: proxied, as: UTF8.self) == "127.0.0.1:\(publicPort)")
    } catch {
      await host.stop()
      throw error
    }

    await host.stop()
    #expect(!SwiftWebDevPortProbe.isListening(host: "127.0.0.1", port: publicPort))
  }

  @Test(.timeLimit(.minutes(1)))
  func devHostDoesNotTreatForeignListenerAsReady() async throws {
    let occupier = try SwiftWebDevTestWorker.start(responseBody: "occupied")
    defer {
      do {
        try occupier.stop()
      } catch {
        Issue.record("SwiftWeb dev test port occupier shutdown failed: \(String(describing: error))")
      }
    }

    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHostForeignListenerTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb dev host foreign listener test cleanup failed: \(String(describing: error))")
      }
    }

    let eventLog = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try eventLog.reset()
    let host = SwiftWebDevHost(
      configuration: SwiftWebDevRuntimeConfiguration(
        packageDirectory: root,
        host: "127.0.0.1",
        port: occupier.target.port,
        readinessTimeout: 1
      ),
      devToken: "test-token",
      eventLog: eventLog,
      workerRegistry: SwiftWebDevWorkerRegistry(),
      logger: Logger(label: "codes.swiftweb.tests.dev-host")
    )

    do {
      try await host.start()
      await host.stop()
      Issue.record("SwiftWeb dev host should not become ready on a port owned by another listener")
    } catch {
      await host.stop()
    }
  }

  @Test(.timeLimit(.minutes(1)))
  func devHostStreamsWorkerServerSentEventsWithoutWaitingForConnectionClose() async throws {
    let publicPort = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHostSSETests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb dev host SSE test cleanup failed: \(String(describing: error))")
      }
    }

    let worker = try await SwiftWebDevTestServerSentEventWorker.start(event: "data: worker-ready\n\n")

    let eventLog = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try eventLog.reset()
    let registry = SwiftWebDevWorkerRegistry()
    let host = SwiftWebDevHost(
      configuration: SwiftWebDevRuntimeConfiguration(
        packageDirectory: root,
        host: "127.0.0.1",
        port: publicPort,
        readinessTimeout: 2
      ),
      devToken: "test-token",
      eventLog: eventLog,
      workerRegistry: registry,
      logger: Logger(label: "codes.swiftweb.tests.dev-host")
    )
    do {
      try await host.start()
      registry.activate(worker.target)

      let event = try await fetchFirstServerSentEvent(
        "http://127.0.0.1:\(publicPort)/events"
      )
      #expect(event.contains("data: worker-ready"))
    } catch {
      await host.stop()
      await worker.stop()
      throw error
    }

    await host.stop()
    await worker.stop()
  }

  @Test(.timeLimit(.minutes(1)))
  func devHostStreamsHotReloadEventsWithoutWaitingForConnectionClose() async throws {
    let publicPort = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevHostEventsTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb dev host events test cleanup failed: \(String(describing: error))")
      }
    }

    let eventLog = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try eventLog.reset()
    let host = SwiftWebDevHost(
      configuration: SwiftWebDevRuntimeConfiguration(
        packageDirectory: root,
        host: "127.0.0.1",
        port: publicPort,
        readinessTimeout: 2
      ),
      devToken: "test-token",
      eventLog: eventLog,
      workerRegistry: SwiftWebDevWorkerRegistry(),
      logger: Logger(label: "codes.swiftweb.tests.dev-host")
    )
    do {
      try await host.start()

      let event = try await fetchFirstServerSentEvent(
        "http://127.0.0.1:\(publicPort)/__swiftweb/dev/events?token=test-token"
      )
      #expect(event.contains("event: connected"))
      #expect(event.contains(#""kind":"connected""#))
    } catch {
      await host.stop()
      throw error
    }

    await host.stop()
  }

  @Test(.timeLimit(.minutes(1)))
  func devHostStreamsMultipleHotReloadEventsOnOneConnection() async throws {
    let publicPort = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent(
        "SwiftWebDevHostMultipleEventsTests-\(UUID().uuidString)",
        isDirectory: true
      )
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb dev host multi-event test cleanup failed: \(String(describing: error))")
      }
    }

    let eventLog = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
    try eventLog.reset()
    try eventLog.append(
      SwiftWebDevEvent(
        kind: .stylePatch,
        stylePatch: SwiftWebDevStylePatch(css: ".counter { color: green; }"),
        changedPaths: ["Sources/App/Counter.css"]
      ))
    try eventLog.append(
      SwiftWebDevEvent(
        kind: .clientBuildStarted,
        message: "Client runtime rebuilding",
        changedPaths: ["Sources/App/ClientCounter.swift"]
      ))
    try eventLog.append(
      SwiftWebDevEvent(
        kind: .serverBuildStarted,
        message: "Worker rebuilding",
        changedPaths: ["Sources/App/CounterPage.swift"]
      ))

    let host = SwiftWebDevHost(
      configuration: SwiftWebDevRuntimeConfiguration(
        packageDirectory: root,
        host: "127.0.0.1",
        port: publicPort,
        readinessTimeout: 2
      ),
      devToken: "test-token",
      eventLog: eventLog,
      workerRegistry: SwiftWebDevWorkerRegistry(),
      logger: Logger(label: "codes.swiftweb.tests.dev-host")
    )
    do {
      try await host.start()

      let events = try await fetchServerSentEvents(
        "http://127.0.0.1:\(publicPort)/__swiftweb/dev/events?token=test-token",
        count: 4
      )
      #expect(events[0].contains("event: connected"))
      #expect(events[1].contains("event: stylePatch"))
      #expect(events[2].contains("event: clientBuildStarted"))
      #expect(events[3].contains("event: serverBuildStarted"))
    } catch {
      await host.stop()
      throw error
    }

    await host.stop()
  }

  @Test
  func buildArtifactCleanerRemovesGeneratedBuildCachesOnly() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebDevCleanerTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {}
    }

    let generatedBuild = root.appendingPathComponent(".swiftweb/generated/.build")
    let storyboardBuild = root.appendingPathComponent(
      ".swiftweb/storyboard/.swiftweb/generated/.build")
    let storyboardSource = root.appendingPathComponent(".swiftweb/storyboard/Sources/App/App.swift")
    let generatedDevSource = root.appendingPathComponent(
      ".swiftweb/generated/dev/Sources/AppDevelopmentServerLauncher/ServerLauncher.swift")
    let devLog = root.appendingPathComponent(".swiftweb/generated/.build/server/hmr-events.jsonl")
    let wasmBuild = root.appendingPathComponent(".swiftweb/generated/wasm-build/server")
    let regularFile = root.appendingPathComponent(
      ".swiftweb/generated/Sources/AppServerLauncher/ServerLauncher.swift")
    try write("build", to: generatedBuild.appendingPathComponent("debug/app-server"))
    try write("build", to: storyboardBuild.appendingPathComponent("release/runtime.wasm"))
    try write("event", to: devLog)
    try write("wasm", to: wasmBuild.appendingPathComponent("release/runtime.wasm"))
    try write("source", to: storyboardSource)
    try write("source", to: generatedDevSource)
    try write("source", to: regularFile)

    let report = try SwiftWebDevBuildArtifactCleaner().cleanGeneratedArtifacts(in: root)

    #expect(report.removedPaths.contains(where: { $0.hasSuffix(".swiftweb/generated/.build") }))
    #expect(
      report.removedPaths.contains(where: {
        $0.hasSuffix(".swiftweb/storyboard/.swiftweb/generated/.build")
      }))
    #expect(!FileManager.default.fileExists(atPath: generatedBuild.path))
    #expect(!FileManager.default.fileExists(atPath: storyboardBuild.path))
    #expect(!FileManager.default.fileExists(atPath: wasmBuild.path))
    #expect(FileManager.default.fileExists(atPath: storyboardSource.path))
    #expect(FileManager.default.fileExists(atPath: generatedDevSource.path))
    #expect(FileManager.default.fileExists(atPath: regularFile.path))
  }

  @Test
  func hostSwiftToolchainPrefersConfigurationOverride() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebHostSwiftOverrideTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb host swift override test cleanup failed: \(String(describing: error))")
      }
    }

    let swiftURL = try makeExecutable(named: "swift", in: root.appendingPathComponent("explicit/bin"))
    let configuration = SwiftWebDevRuntimeConfiguration(
      packageDirectory: root,
      hostSwiftExecutableURL: swiftURL
    )

    let toolchain = try SwiftWebHostSwiftToolchain.resolve(
      configuration: configuration,
      environment: [:]
    )

    #expect(toolchain.swiftExecutableURL == swiftURL)
    #expect(toolchain.applying(to: ["PATH": "/usr/bin"])["PATH"] == "\(swiftURL.deletingLastPathComponent().path):/usr/bin")
  }

  @Test
  func hostSwiftToolchainReadsEnvironmentOverrides() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebHostSwiftEnvironmentTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb host swift environment test cleanup failed: \(String(describing: error))")
      }
    }

    let swiftURL = try makeExecutable(named: "swift", in: root.appendingPathComponent("environment/bin"))
    let configuration = SwiftWebDevRuntimeConfiguration(packageDirectory: root)

    let toolchain = try SwiftWebHostSwiftToolchain.resolve(
      configuration: configuration,
      environment: ["SWIFT_WEB_HOST_SWIFT": swiftURL.path]
    )

    #expect(toolchain.swiftExecutableURL == swiftURL)
  }

  @Test
  func hostSwiftToolchainReadsToolchainBinOverride() throws {
    let root = FileManager.default.temporaryDirectory
      .appendingPathComponent("SwiftWebHostSwiftBinTests-\(UUID().uuidString)", isDirectory: true)
    defer {
      do {
        try FileManager.default.removeItem(at: root)
      } catch {
        Issue.record("SwiftWeb host swift bin test cleanup failed: \(String(describing: error))")
      }
    }

    let binURL = root.appendingPathComponent("toolchain/bin")
    let swiftURL = try makeExecutable(named: "swift", in: binURL)
    let configuration = SwiftWebDevRuntimeConfiguration(packageDirectory: root)

    let toolchain = try SwiftWebHostSwiftToolchain.resolve(
      configuration: configuration,
      environment: ["SWIFT_WEB_HOST_TOOLCHAIN_BIN": binURL.path]
    )

    #expect(toolchain.swiftExecutableURL == swiftURL)
  }
}

private func makeExecutable(named name: String, in directory: URL) throws -> URL {
  try FileManager.default.createDirectory(
    at: directory,
    withIntermediateDirectories: true
  )
  let url = directory.appendingPathComponent(name)
  try "#!/bin/sh\nexit 0\n".write(to: url, atomically: true, encoding: .utf8)
  try FileManager.default.setAttributes(
    [.posixPermissions: 0o755],
    ofItemAtPath: url.path
  )
  return url.standardizedFileURL
}

private func write(_ contents: String, to url: URL) throws {
  try FileManager.default.createDirectory(
    at: url.deletingLastPathComponent(),
    withIntermediateDirectories: true
  )
  try contents.write(to: url, atomically: true, encoding: .utf8)
}

private func fetch(_ urlString: String) async throws -> Data {
  guard let url = URL(string: urlString) else {
    throw SwiftWebDevHMRError.invalidURL(urlString)
  }
  let (data, response) = try await URLSession.shared.data(from: url)
  guard let httpResponse = response as? HTTPURLResponse else {
    throw SwiftWebDevHMRError.nonHTTPResponse
  }
  guard (200..<300).contains(httpResponse.statusCode) else {
    throw SwiftWebDevHMRError.unexpectedStatus(httpResponse.statusCode)
  }
  return data
}

private func fetchFirstServerSentEvent(_ urlString: String) async throws -> String {
  let events = try await fetchServerSentEvents(urlString, count: 1)
  guard let event = events.first else {
    throw SwiftWebDevHMRError.serverSentEventTimeout
  }
  return event
}

private func fetchServerSentEvents(_ urlString: String, count: Int) async throws -> [String] {
  return try await withThrowingTaskGroup(of: [String].self) { group in
    group.addTask {
      guard let url = URL(string: urlString) else {
        throw SwiftWebDevHMRError.invalidURL(urlString)
      }
      var request = URLRequest(url: url)
      request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
      let (bytes, response) = try await URLSession.shared.bytes(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw SwiftWebDevHMRError.nonHTTPResponse
      }
      guard (200..<300).contains(httpResponse.statusCode) else {
        throw SwiftWebDevHMRError.unexpectedStatus(httpResponse.statusCode)
      }
      var events: [String] = []
      var eventBytes: [UInt8] = []
      for try await byte in bytes {
        eventBytes.append(byte)
        if eventBytes.count >= 2,
           eventBytes[eventBytes.count - 2] == UInt8(ascii: "\n"),
           eventBytes[eventBytes.count - 1] == UInt8(ascii: "\n") {
          events.append(String(decoding: eventBytes, as: UTF8.self))
          eventBytes.removeAll(keepingCapacity: true)
          if events.count == count {
            return events
          }
        }
      }
      if !eventBytes.isEmpty {
        events.append(String(decoding: eventBytes, as: UTF8.self))
      }
      return events
    }
    group.addTask {
      try await Task.sleep(nanoseconds: 2_000_000_000)
      throw SwiftWebDevHMRError.serverSentEventTimeout
    }

    defer {
      group.cancelAll()
    }

    guard let events = try await group.next() else {
      throw SwiftWebDevHMRError.serverSentEventTimeout
    }
    return events
  }
}

private enum SwiftWebDevHMRError: Error {
  case invalidURL(String)
  case nonHTTPResponse
  case unexpectedStatus(Int)
  case workerStartupCleanupFailed(start: String, cleanup: String)
  case serverSentEventTimeout
}

private final class SwiftWebDevTestWorker: Sendable {
  private struct State: Sendable {
    var channel: (any Channel)?
    var eventLoopGroup: MultiThreadedEventLoopGroup?
  }

  let target: SwiftWebDevWorkerTarget
  private let responseBody: String
  private let echoHeaderName: String?
  private let state = Mutex(State())

  private init(target: SwiftWebDevWorkerTarget, responseBody: String, echoHeaderName: String?) {
    self.target = target
    self.responseBody = responseBody
    self.echoHeaderName = echoHeaderName
  }

  static func start(responseBody: String) throws -> SwiftWebDevTestWorker {
    let port = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let worker = SwiftWebDevTestWorker(
      target: SwiftWebDevWorkerTarget(host: "127.0.0.1", port: port),
      responseBody: responseBody,
      echoHeaderName: nil
    )
    try worker.start()
    return worker
  }

  static func startEchoingHeader(_ headerName: String) throws -> SwiftWebDevTestWorker {
    let port = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let worker = SwiftWebDevTestWorker(
      target: SwiftWebDevWorkerTarget(host: "127.0.0.1", port: port),
      responseBody: "",
      echoHeaderName: headerName
    )
    try worker.start()
    return worker
  }

  func stop() throws {
    let resources = state.withLock { state in
      let resources = (state.channel, state.eventLoopGroup)
      state.channel = nil
      state.eventLoopGroup = nil
      return resources
    }

    if let channel = resources.0 {
      try channel.close().wait()
    }
    if let eventLoopGroup = resources.1 {
      try eventLoopGroup.syncShutdownGracefully()
    }
  }

  private func start() throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let responseBody = responseBody
    let echoHeaderName = echoHeaderName
    let bootstrap = ServerBootstrap(group: eventLoopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: 16)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline().flatMap {
          channel.pipeline.addHandler(
            SwiftWebDevTestWorkerHandler(
              responseBody: responseBody,
              echoHeaderName: echoHeaderName
            )
          )
        }
      }
      .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

    do {
      let channel = try bootstrap.bind(host: target.host, port: target.port).wait()
      state.withLock { state in
        state.channel = channel
        state.eventLoopGroup = eventLoopGroup
      }
    } catch {
      do {
        try eventLoopGroup.syncShutdownGracefully()
      } catch let shutdownError {
        throw SwiftWebDevHMRError.workerStartupCleanupFailed(
          start: String(describing: error),
          cleanup: String(describing: shutdownError)
        )
      }
      throw error
    }
  }
}

private final class SwiftWebDevTestWorkerHandler: ChannelInboundHandler, Sendable {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  private let responseBody: String
  private let echoHeaderName: String?
  private let echoedHeaderValue = Mutex<String?>(nil)

  init(responseBody: String, echoHeaderName: String?) {
    self.responseBody = responseBody
    self.echoHeaderName = echoHeaderName
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    switch unwrapInboundIn(data) {
    case .head(let head):
      if let echoHeaderName {
        echoedHeaderValue.withLock { value in
          value = head.headers.first(name: echoHeaderName)
        }
      }
      return
    case .body:
      return
    case .end:
      break
    }

    let body = echoHeaderName == nil
      ? responseBody
      : (echoedHeaderValue.withLock { $0 } ?? "")
    let bytes = Array(body.utf8)
    var headers = HTTPHeaders()
    headers.add(name: "content-type", value: "text/plain; charset=utf-8")
    headers.add(name: "content-length", value: String(bytes.count))
    let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
    context.write(wrapOutboundOut(.head(head)), promise: nil)
    var buffer = context.channel.allocator.buffer(capacity: bytes.count)
    buffer.writeBytes(bytes)
    context.write(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
    context.writeAndFlush(wrapOutboundOut(.end(nil)), promise: nil)
  }
}

private final class SwiftWebDevTestServerSentEventWorker: Sendable {
  private struct State: Sendable {
    var channel: (any Channel)?
    var eventLoopGroup: MultiThreadedEventLoopGroup?
  }

  let target: SwiftWebDevWorkerTarget
  private let event: String
  private let state = Mutex(State())

  private init(target: SwiftWebDevWorkerTarget, event: String) {
    self.target = target
    self.event = event
  }

  static func start(event: String) async throws -> SwiftWebDevTestServerSentEventWorker {
    let port = try SwiftWebDevPortAllocator.allocateLoopbackPort()
    let worker = SwiftWebDevTestServerSentEventWorker(
      target: SwiftWebDevWorkerTarget(host: "127.0.0.1", port: port),
      event: event
    )
    try worker.start()
    return worker
  }

  func stop() async {
    let resources = state.withLock { state in
      let resources = (state.channel, state.eventLoopGroup)
      state.channel = nil
      state.eventLoopGroup = nil
      return resources
    }

    if let channel = resources.0 {
      do {
        try await channel.close().get()
      } catch {
        Issue.record("SwiftWeb dev SSE worker channel close failed: \(String(describing: error))")
      }
    }
    if let eventLoopGroup = resources.1 {
      do {
        try await Self.shutdown(eventLoopGroup)
      } catch {
        Issue.record("SwiftWeb dev SSE worker shutdown failed: \(String(describing: error))")
      }
    }
  }

  private func start() throws {
    let eventLoopGroup = MultiThreadedEventLoopGroup(numberOfThreads: 1)
    let event = event
    let bootstrap = ServerBootstrap(group: eventLoopGroup)
      .serverChannelOption(ChannelOptions.backlog, value: 16)
      .serverChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)
      .childChannelInitializer { channel in
        channel.pipeline.configureHTTPServerPipeline().flatMap {
          channel.pipeline.addHandler(SwiftWebDevTestServerSentEventWorkerHandler(event: event))
        }
      }
      .childChannelOption(ChannelOptions.socketOption(.so_reuseaddr), value: 1)

    do {
      let channel = try bootstrap.bind(host: target.host, port: target.port).wait()
      state.withLock { state in
        state.channel = channel
        state.eventLoopGroup = eventLoopGroup
      }
    } catch {
      do {
        try eventLoopGroup.syncShutdownGracefully()
      } catch let shutdownError {
        throw SwiftWebDevHMRError.workerStartupCleanupFailed(
          start: String(describing: error),
          cleanup: String(describing: shutdownError)
        )
      }
      throw error
    }
  }

  private static func shutdown(_ eventLoopGroup: MultiThreadedEventLoopGroup) async throws {
    try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, any Error>) in
      eventLoopGroup.shutdownGracefully { error in
        if let error {
          continuation.resume(throwing: error)
        } else {
          continuation.resume()
        }
      }
    }
  }
}

private final class SwiftWebDevTestServerSentEventWorkerHandler: ChannelInboundHandler, Sendable {
  typealias InboundIn = HTTPServerRequestPart
  typealias OutboundOut = HTTPServerResponsePart

  private let event: String

  init(event: String) {
    self.event = event
  }

  func channelRead(context: ChannelHandlerContext, data: NIOAny) {
    guard case .end = unwrapInboundIn(data) else {
      return
    }

    var headers = HTTPHeaders()
    headers.add(name: "content-type", value: "text/event-stream; charset=utf-8")
    headers.add(name: "cache-control", value: "no-cache, no-transform")
    headers.add(name: "connection", value: "keep-alive")
    let head = HTTPResponseHead(version: .http1_1, status: .ok, headers: headers)
    context.write(wrapOutboundOut(.head(head)), promise: nil)

    let bytes = Array(event.utf8)
    var buffer = context.channel.allocator.buffer(capacity: bytes.count)
    buffer.writeBytes(bytes)
    context.writeAndFlush(wrapOutboundOut(.body(.byteBuffer(buffer))), promise: nil)
  }
}
