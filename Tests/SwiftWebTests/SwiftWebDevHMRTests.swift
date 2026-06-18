@testable import SwiftWebDevelopment
import Foundation
import SwiftHTML
import Testing

@Suite
struct SwiftWebDevHMRTests {
    @Test
    func changeClassifierSeparatesStyleClientAndServerChanges() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebDevHMRTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
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
                ),
            ]
        )
        let classifier = SwiftWebDevChangeClassifier(
            appPackageDirectory: root,
            generatedPackage: generated
        )

        let clientPlan = classifier.classify([
            SwiftWebDevFileChange(path: "Sources/App/ClientCounter.swift", url: clientFile, kind: .modified),
        ])
        #expect(clientPlan.clientRuntimes.map(\.componentTypeName) == ["ClientCounter"])
        #expect(clientPlan.styleFiles.isEmpty)
        #expect(!clientPlan.requiresServerRestart)

        let stylePlan = classifier.classify([
            SwiftWebDevFileChange(path: "Sources/App/App.css", url: cssFile, kind: .modified),
        ])
        #expect(stylePlan.styleFiles == [cssFile.standardizedFileURL])
        #expect(stylePlan.clientRuntimes.isEmpty)
        #expect(!stylePlan.requiresServerRestart)

        let serverPlan = classifier.classify([
            SwiftWebDevFileChange(path: "Package.swift", url: packageFile, kind: .modified),
        ])
        #expect(serverPlan.requiresServerRestart)
    }

    @Test
    func changeClassifierMapsAnyComponentInABundleToThatRuntime() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebDevMultiComponentHMRTests-\(UUID().uuidString)", isDirectory: true)
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
                ),
            ]
        )
        let classifier = SwiftWebDevChangeClassifier(
            appPackageDirectory: root,
            generatedPackage: generated
        )

        let shellPlan = classifier.classify([
            SwiftWebDevFileChange(path: "Sources/App/ClientShell.swift", url: shellFile, kind: .modified),
        ])
        let badgePlan = classifier.classify([
            SwiftWebDevFileChange(path: "Sources/App/ClientBadge.swift", url: badgeFile, kind: .modified),
        ])

        #expect(shellPlan.clientRuntimes.map(\.productName) == ["app-wasm-runtime"])
        #expect(badgePlan.clientRuntimes.map(\.productName) == ["app-wasm-runtime"])
        #expect(!shellPlan.requiresServerRestart)
        #expect(!badgePlan.requiresServerRestart)
    }

    @Test
    func wasmBuildInputHashChangesOnlyForBuildInputs() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebWasmBuildInputHasherTests-\(UUID().uuidString)", isDirectory: true)
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
        try log.append(connected)
        try log.append(style)

        #expect(try log.events(after: nil).map(\.kind) == [.connected, .stylePatch])
        #expect(try log.events(after: connected.id).map(\.kind) == [.stylePatch])
    }

    @Test
    func clientManifestSnapshotStoreReturnsRuntimeSchemaHashes() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("SwiftWebDevManifestSnapshotTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let bundleID = ClientBundleID("counter-runtime")
        let store = SwiftWebDevClientManifestSnapshotStore(
            fileURL: root.appendingPathComponent("client-manifest-snapshot.json")
        )
        try store.write(ClientBundleManifest(
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
                ),
            ]
        ))

        let hashes = try store.schemaHashes(for: SwiftWebGeneratedWasmRuntime(
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
            .appendingPathComponent("SwiftWebDevManifestSnapshotErrorTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("SwiftWebDevInitialEventPayloadTests-\(UUID().uuidString)", isDirectory: true)
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
            .appendingPathComponent("SwiftWebDevIncrementalEventPayloadTests-\(UUID().uuidString)", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {}
        }

        let log = SwiftWebDevEventLog(fileURL: root.appendingPathComponent("events.jsonl"))
        try log.reset()
        let oldEvent = SwiftWebDevEvent(kind: .stylePatch, stylePatch: SwiftWebDevStylePatch(css: ".old {}"))
        let nextEvent = SwiftWebDevEvent(kind: .clientComponentUpdate, message: "client updated")
        try log.append(oldEvent)
        try log.append(nextEvent)

        let payload = try await SwiftWebDevHotReload.eventPayload(from: log, after: oldEvent.id)

        #expect(!payload.contains(oldEvent.id))
        #expect(payload.contains(nextEvent.id))
        #expect(payload.contains("event: clientComponentUpdate"))
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
        let nestedComponentID = ComponentID("manual-card")
        let runtimeBundleID = ClientBundleID("main-runtime")
        let html = """
        <main><!--component:manual-counter:begin--><!--component:manual-card:begin--><div data-node="3" data-component="manual-card">Manual</div><!--component:manual-card:end--><!--component:manual-counter:end--></main>
        """
        let manifest = ClientBundleManifest(
            runtimeBundleID: runtimeBundleID,
            bundles: [],
            components: [
                ClientComponentAsset(
                    componentID: nestedComponentID,
                    typeName: "SwiftWebUI.Card",
                    bundleID: runtimeBundleID,
                    loadPolicy: .manual,
                    entrySymbols: [ClientSymbolID("SwiftWebUI.Card")]
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
                    typeName: "SwiftWebUI.Card",
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
        #expect(!annotated.contains(#"data-component="manual-card""#))
        #expect(!annotated.contains(#"data-component-type="SwiftWebUI.Card""#))
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
        let storyboardBuild = root.appendingPathComponent(".swiftweb/storyboard/.swiftweb/generated/.build")
        let storyboardSource = root.appendingPathComponent(".swiftweb/storyboard/Sources/App/App.swift")
        let generatedDevSource = root.appendingPathComponent(".swiftweb/generated/dev/Sources/AppDevelopmentServerLauncher/ServerLauncher.swift")
        let devLog = root.appendingPathComponent(".swiftweb/generated/.build/server/hmr-events.jsonl")
        let regularFile = root.appendingPathComponent(".swiftweb/generated/Sources/AppServerLauncher/ServerLauncher.swift")
        try write("build", to: generatedBuild.appendingPathComponent("debug/app-server"))
        try write("build", to: storyboardBuild.appendingPathComponent("release/runtime.wasm"))
        try write("event", to: devLog)
        try write("source", to: storyboardSource)
        try write("source", to: generatedDevSource)
        try write("source", to: regularFile)

        let report = try SwiftWebDevBuildArtifactCleaner().cleanGeneratedArtifacts(in: root)

        #expect(report.removedPaths.contains(where: { $0.hasSuffix(".swiftweb/generated/.build") }))
        #expect(report.removedPaths.contains(where: { $0.hasSuffix(".swiftweb/storyboard/.swiftweb/generated/.build") }))
        #expect(!FileManager.default.fileExists(atPath: generatedBuild.path))
        #expect(!FileManager.default.fileExists(atPath: storyboardBuild.path))
        #expect(FileManager.default.fileExists(atPath: storyboardSource.path))
        #expect(FileManager.default.fileExists(atPath: generatedDevSource.path))
        #expect(FileManager.default.fileExists(atPath: regularFile.path))
    }
}

private func write(_ contents: String, to url: URL) throws {
    try FileManager.default.createDirectory(
        at: url.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try contents.write(to: url, atomically: true, encoding: .utf8)
}
