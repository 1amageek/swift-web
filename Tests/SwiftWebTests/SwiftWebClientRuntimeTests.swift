@testable import SwiftWeb
import Testing

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

        #expect(runtime.hostScriptPath == "/__swiftweb/wasm/runtime-host.js?v=17")
        #expect(runtime.javaScriptKitRuntimePath == "/__swiftweb/wasm/javascript-kit-runtime.js?v=1")
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
}
