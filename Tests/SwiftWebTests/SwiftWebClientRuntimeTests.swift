@testable import SwiftWeb
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
    @Environment(\.runtimeTestValue) private var environmentValue: String
    @State private var value = 0

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            value += 1
        }) {
            "\(environmentValue) \(value)"
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
            .environment(\.runtimeTestValue, "server")
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
}
