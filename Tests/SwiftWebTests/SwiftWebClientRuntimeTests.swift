@testable import SwiftWeb
@testable import SwiftWebCore
import SwiftHTML
import Testing

private struct RuntimeTestEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = "default"
}

private extension EnvironmentValues {
    var runtimeTestValue: String {
        get { self[RuntimeTestEnvironmentKey.self] }
        set { self[RuntimeTestEnvironmentKey.self] = newValue }
    }
}

private struct RuntimeStatefulComponent: ClientComponent {
    @Environment(RuntimeTestEnvironmentKey.self) private var environmentValue: String
    @State private var value = 0

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            value += 1
        }) {
            "\(environmentValue) \(value)"
        }
    }
}

private struct RuntimeChartComponent: ClientComponent {
    static let loadPolicy: LoadPolicy = .visible

    var body: some HTML {
        button(.type(ButtonType.button)) {
            "Chart"
        }
    }
}

private struct RuntimeEditorComponent: ClientComponent {
    static let loadPolicy: LoadPolicy = .interaction
    static let bundle: BundlePolicy = .shared("workspace")

    var body: some HTML {
        button(.type(ButtonType.button)) {
            "Editor"
        }
    }
}

private struct RuntimeSplitShell: Component {
    var body: some HTML {
        div {
            RuntimeChartComponent()
            RuntimeEditorComponent()
        }
    }
}

@Suite
struct SwiftWebClientRuntimeTests {
    @Test
    func runtimeModesDefineHydrationMarkerAndClosureCapturePolicy() {
        let wasm = SwiftWebClientRuntime.wasm(
            SwiftWebWasmClientRuntime(
                manifestPath: "/assets/swift-web-client.json",
                runtimeAssetPath: "/assets/swift-web-runtime.wasm"
            )
        )

        #expect(!SwiftWebClientRuntime.disabled.emitsBrowserHydrationMarkers)
        #expect(!SwiftWebClientRuntime.disabled.capturesClientHandlerClosures)

        #expect(wasm.emitsBrowserHydrationMarkers)
        #expect(!wasm.capturesClientHandlerClosures)
    }

    @Test
    func wasmRuntimeCarriesDefaultHostScriptPath() {
        let runtime = SwiftWebWasmClientRuntime(
            manifestPath: "/assets/swift-web-client.json",
            runtimeAssetPath: "/assets/swift-web-runtime.wasm"
        )

        // Reference the route constants, not literal versions: the cache-bust
        // token is a content hash that changes on every script edit, so pinning
        // the literal here would force a test rewrite on each change.
        #expect(runtime.hostScriptPath == SwiftWebWasmRuntimeRoutes.versionedHostScriptPath)
        #expect(runtime.javaScriptKitRuntimePath == SwiftWebWasmRuntimeRoutes.versionedJavaScriptKitRuntimePath)
        #expect(runtime.hostScriptPath.hasPrefix("\(SwiftWebWasmRuntimeRoutes.hostScriptPath)?v="))
        #expect(runtime.metricsMode == .summary)
    }

    @Test
    func wasmRuntimeCanEnableDetailedBrowserMetrics() {
        let runtime = SwiftWebWasmClientRuntime(
            manifestPath: "/assets/swift-web-client.json",
            runtimeAssetPath: "/assets/swift-web-runtime.wasm",
            metricsMode: .detailed
        )

        #expect(runtime.metricsMode == .detailed)
    }

    @Test
    func wasmManifestCarriesComponentStateAndEnvironmentSchemaHashes() throws {
        let artifact = RuntimeStatefulComponent()
            .environment(RuntimeTestEnvironmentKey.self, "server")
            .renderArtifact()
        let component = try #require(artifact.hydration.components.first)
        let unqualifiedTypeName = component.typeName.split(separator: ".").last.map(String.init) ?? component.typeName
        let bundleID = ClientBundleID("runtime-stateful")
        let runtime = SwiftWebWasmClientRuntime(
            manifestPath: "/assets/swift-web-client.json",
            runtimeAssetPath: "/assets/swift-web-runtime.wasm",
            additionalBundles: [
                SwiftWebWasmClientBundle(
                    id: bundleID,
                    componentTypeName: unqualifiedTypeName,
                    assetPath: "/assets/runtime-stateful.wasm"
                ),
            ]
        )

        let manifest = SwiftWebWasmClientManifestBuilder.manifest(
            from: artifact,
            runtime: runtime
        )
        let asset = try #require(manifest.component(component.id))
        let bundle = try #require(manifest.bundle(bundleID))

        #expect(asset.bundleID == bundleID)
        #expect(asset.stateSchemaHash == component.stateSchemaHash)
        #expect(asset.environmentSchemaHash == component.environmentSnapshot.schemaHash)
        #expect(bundle.kind == .component)
        #expect(try #require(bundle.asset).path == "/assets/runtime-stateful.wasm")
    }

    @Test
    func wasmManifestUsesResolvedSplitBundleContracts() throws {
        let artifact = RuntimeSplitShell().renderArtifact()
        let chart = try #require(artifact.hydration.components.first { component in
            component.typeName.hasSuffix(".RuntimeChartComponent")
                || component.typeName == "RuntimeChartComponent"
        })
        let editor = try #require(artifact.hydration.components.first { component in
            component.typeName.hasSuffix(".RuntimeEditorComponent")
                || component.typeName == "RuntimeEditorComponent"
        })
        let chartBundleID = try #require(chart.bundleID)
        let editorBundleID = try #require(editor.bundleID)
        let chartTypeName = chart.typeName.split(separator: ".").last.map(String.init) ?? chart.typeName
        let editorTypeName = editor.typeName.split(separator: ".").last.map(String.init) ?? editor.typeName

        #expect(chart.loadPolicy == .visible)
        #expect(editor.loadPolicy == .interaction)
        #expect(editorBundleID == ClientBundleID("shared-workspace"))

        let runtime = SwiftWebWasmClientRuntime(
            manifestPath: "/assets/swift-web-client.json",
            runtimeAssetPath: "/assets/main.wasm",
            additionalBundles: [
                SwiftWebWasmClientBundle(
                    id: chartBundleID,
                    componentTypeNames: [chartTypeName],
                    assetPath: "/assets/chart.wasm"
                ),
                SwiftWebWasmClientBundle(
                    id: editorBundleID,
                    componentTypeNames: [editorTypeName],
                    assetPath: "/assets/workspace.wasm"
                ),
            ]
        )

        let manifest = SwiftWebWasmClientManifestBuilder.manifest(
            from: artifact,
            runtime: runtime
        )
        let chartAsset = try #require(manifest.component(chart.id))
        let editorAsset = try #require(manifest.component(editor.id))
        let chartBundle = try #require(manifest.bundle(chartBundleID))
        let editorBundle = try #require(manifest.bundle(editorBundleID))

        #expect(chartAsset.bundleID == chartBundleID)
        #expect(chartAsset.loadPolicy == .visible)
        #expect(editorAsset.bundleID == editorBundleID)
        #expect(editorAsset.loadPolicy == .interaction)
        #expect(chartBundle.components == [chart.id])
        #expect(editorBundle.components == [editor.id])
        #expect(try #require(chartBundle.asset).path == "/assets/chart.wasm")
        #expect(try #require(editorBundle.asset).path == "/assets/workspace.wasm")
    }

    @Test
    func wasmManifestPreservesLogicalBundleIDsWhenPhysicalAssetIsShared() throws {
        let artifact = RuntimeSplitShell().renderArtifact()
        let chart = try #require(artifact.hydration.components.first { component in
            component.typeName.hasSuffix(".RuntimeChartComponent")
                || component.typeName == "RuntimeChartComponent"
        })
        let editor = try #require(artifact.hydration.components.first { component in
            component.typeName.hasSuffix(".RuntimeEditorComponent")
                || component.typeName == "RuntimeEditorComponent"
        })
        let chartBundleID = try #require(chart.bundleID)
        let editorBundleID = try #require(editor.bundleID)
        let chartTypeName = chart.typeName.split(separator: ".").last.map(String.init) ?? chart.typeName
        let editorTypeName = editor.typeName.split(separator: ".").last.map(String.init) ?? editor.typeName

        let runtime = SwiftWebWasmClientRuntime(
            manifestPath: "/assets/swift-web-client.json",
            runtimeAssetPath: "/assets/main.wasm",
            additionalBundles: [
                SwiftWebWasmClientBundle(
                    id: chartBundleID,
                    componentTypeNames: [chartTypeName],
                    assetPath: "/assets/deferred.wasm"
                ),
                SwiftWebWasmClientBundle(
                    id: editorBundleID,
                    componentTypeNames: [editorTypeName],
                    assetPath: "/assets/deferred.wasm"
                ),
            ]
        )

        let manifest = SwiftWebWasmClientManifestBuilder.manifest(
            from: artifact,
            runtime: runtime
        )
        let chartAsset = try #require(manifest.component(chart.id))
        let editorAsset = try #require(manifest.component(editor.id))
        let chartBundle = try #require(manifest.bundle(chartBundleID))
        let editorBundle = try #require(manifest.bundle(editorBundleID))

        #expect(chartAsset.bundleID == chartBundleID)
        #expect(editorAsset.bundleID == editorBundleID)
        #expect(try #require(chartBundle.asset).path == "/assets/deferred.wasm")
        #expect(try #require(editorBundle.asset).path == "/assets/deferred.wasm")
    }
}
