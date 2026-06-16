@testable import SwiftWeb
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
    func boundaryAnnotatorAddsDevMetadataToClientComponentRootElement() {
        let componentID = ComponentID("component-1")
        let nestedComponentID = ComponentID("nested")
        let html = """
        <main><!--swift-html-component:component-1:begin--><!--swift-html-component:nested:begin--><div data-swift-node="3">Counter</div><!--swift-html-component:nested:end--><!--swift-html-component:component-1:end--></main>
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

        #expect(annotated.contains(#"data-swift-component="component-1""#))
        #expect(annotated.contains(#"data-swift-hmr-boundary="true""#))
        #expect(annotated.contains(#"data-swift-state-schema=""#))
        #expect(annotated.contains(#"data-swift-component-type="Demo.Counter""#))
        #expect(annotated.contains(#"data-swift-bundle="counter-runtime""#))
        #expect(!annotated.contains(#"data-swift-component="nested""#))
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
        let devLog = root.appendingPathComponent(".swiftweb/generated/.build/server/hmr-events.jsonl")
        let regularFile = root.appendingPathComponent(".swiftweb/generated/Sources/AppServerLauncher/ServerLauncher.swift")
        try write("build", to: generatedBuild.appendingPathComponent("debug/app-server"))
        try write("build", to: storyboardBuild.appendingPathComponent("release/runtime.wasm"))
        try write("event", to: devLog)
        try write("source", to: storyboardSource)
        try write("source", to: regularFile)

        let report = try SwiftWebDevBuildArtifactCleaner().cleanGeneratedArtifacts(in: root)

        #expect(report.removedPaths.contains(where: { $0.hasSuffix(".swiftweb/generated/.build") }))
        #expect(report.removedPaths.contains(where: { $0.hasSuffix(".swiftweb/storyboard/.swiftweb/generated/.build") }))
        #expect(!FileManager.default.fileExists(atPath: generatedBuild.path))
        #expect(!FileManager.default.fileExists(atPath: storyboardBuild.path))
        #expect(FileManager.default.fileExists(atPath: storyboardSource.path))
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
