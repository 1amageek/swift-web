import Foundation
import SwiftHTML
import Testing

@testable import SwiftWeb
@testable import SwiftWebCore
@testable import SwiftWebDevelopment

@Suite
struct SwiftWebDiagnosticsTests {
  @Test
  func formatsHydrationDiagnosticsForDeveloperOutput() {
    let diagnostic = RenderDiagnostic(
      code: .runtimeOnlyEnvironmentInClientComponent,
      severity: .warning,
      message: "SampleClient reads runtime-only environment value Library",
      componentID: ComponentID("c1"),
      componentType: "SampleClient",
      path: "root",
      hint: "Provide the runtime environment from the client runtime."
    )

    let lines = SwiftWebDiagnostics.formattedLines(for: [diagnostic])

    #if DEBUG
      #expect(SwiftWebDiagnostics.isEnabled)
    #else
      #expect(!SwiftWebDiagnostics.isEnabled)
    #endif

    #expect(lines.count == 1)
    #expect(lines[0].contains("SwiftWeb [warning]"))
    #expect(lines[0].contains("swift-html.hydration.runtime-only-environment-in-client-component"))
    #expect(lines[0].contains("component=SampleClient"))
    #expect(lines[0].contains("path=root"))
    #expect(lines[0].contains("id=c1"))
    #expect(lines[0].contains("hint: Provide the runtime environment"))
  }

  @Test
  func clientRuntimeInjectorAddsWasmDescriptorAndPreloadLinks() throws {
    let runtime = SwiftWebWasmClientRuntime(
      manifestPath: "/assets/swift-web-client.json",
      runtimeAssetPath: "/assets/runtime.wasm"
    )
    let descriptor = SwiftWebClientRuntimeDescriptor(
      mode: .wasm,
      hydrationIndex: .empty,
      wasm: runtime
    )

    let html = try SwiftWebClientRuntimeHTMLInjector().inject(
      into: "<html><head></head><body><main>Counter</main></body></html>",
      descriptor: descriptor
    )

    #expect(
      html.contains(
        "<link rel=\"preload\" href=\"/assets/runtime.wasm\" as=\"fetch\" type=\"application/wasm\" crossorigin=\"anonymous\">"
      ))
    #expect(
      html.contains(
        "<link rel=\"preload\" href=\"/assets/swift-web-client.json\" as=\"fetch\" type=\"application/json\" crossorigin=\"anonymous\">"
      ))
    #expect(html.contains("\"mode\":\"wasm\""))
    // Build expectations from the route constants, not literal versions: the
    // host script's cache-bust token is a content hash that changes on every
    // script edit, so a pinned literal would force a rewrite each time.
    #expect(
      html.contains(
        "\"hostScriptPath\":\"\\/__swiftweb\\/wasm\\/runtime-host.js?v=\(SwiftWebWasmRuntimeRoutes.hostScriptVersion)\""
      ))
    #expect(
      html.contains(
        "\"javaScriptKitRuntimePath\":\"\\/__swiftweb\\/wasm\\/javascript-kit-runtime.js?v=\(SwiftWebWasmRuntimeRoutes.javaScriptKitRuntimeVersion)\""
      ))
    #expect(html.contains("\"metricsMode\":\"summary\""))
    #expect(
      html.contains(
        "<script type=\"module\" src=\"\(SwiftWebWasmRuntimeRoutes.versionedHostScriptPath)\"></script></body>"
      ))
  }

  @Test
  func clientRuntimeInjectorUsesInlineManifestWithoutManifestPreload() throws {
    let runtime = SwiftWebWasmClientRuntime(
      manifestPath: "/assets/swift-web-client.json",
      runtimeAssetPath: "/assets/runtime.wasm"
    )
    let descriptor = SwiftWebClientRuntimeDescriptor(
      mode: .wasm,
      hydrationIndex: .empty,
      manifest: ClientBundleManifest(
        runtimeBundleID: ClientBundleID("runtime"),
        bundles: [
          ClientBundleRecord(
            id: ClientBundleID("runtime"),
            kind: .runtime,
            asset: WasmAsset(path: "/assets/runtime.wasm"),
            symbols: [ClientSymbolID("runtime")]
          )
        ]
      ),
      wasm: runtime
    )

    let html = try SwiftWebClientRuntimeHTMLInjector().inject(
      into: "<html><head></head><body><main>Counter</main></body></html>",
      descriptor: descriptor
    )

    #expect(
      html.contains(
        "<link rel=\"preload\" href=\"/assets/runtime.wasm\" as=\"fetch\" type=\"application/wasm\" crossorigin=\"anonymous\">"
      ))
    #expect(!html.contains("<link rel=\"preload\" href=\"/assets/swift-web-client.json\""))
    #expect(html.contains("\"manifest\""))
    #expect(html.contains("\"runtimeBundleID\""))
  }

  @Test
  func wasmRuntimeHostScriptUsesWasmExportsAndManifestLoading() {
    let source = SwiftWebWasmRuntimeHostScript.source

    #expect(source.contains("swiftweb_bootstrap"))
    #expect(source.contains("swiftweb_dispatch_event"))
    #expect(source.contains("swiftweb_snapshot_state"))
    #expect(source.contains("applyHotUpdate"))
    #expect(source.contains("window.__swiftWebWasmRuntime"))
    #expect(source.contains("WebAssembly.instantiateStreaming"))
    #expect(source.contains("WebAssembly.compile"))
    #expect(source.contains("swiftWebLoadJavaScriptKitRuntime"))
    #expect(source.contains("javascript_kit: swiftRuntime.wasmImports"))
    #expect(source.contains("bjs: swiftWebBridgeJSStubs()"))
    #expect(source.contains("swiftRuntime.setInstance(instance)"))
    #expect(source.contains("swiftRuntime.main()"))
    #expect(source.contains("manifest.runtimeBundleID"))
    #expect(source.contains("data-event-"))
    #expect(source.contains("\"pointerdown\""))
    #expect(source.contains("\"dragover\""))
    #expect(source.contains("__swiftWebWasmRuntimeStatus"))
    #expect(source.contains("wasmStatus"))
    #expect(source.contains("__swiftWebWasmRuntimeMetrics"))
    #expect(source.contains("wasm-runtime-metrics"))
    #expect(source.contains("data-wasm-phase"))
    #expect(source.contains("setMetricAttribute(\"ready-ms\""))
    #expect(source.contains("setMetricAttribute(\"javascript-kit-import-ms\""))
    #expect(source.contains("metricsMode()"))
    #expect(source.contains("instantiateBundleDetailed"))
    #expect(source.contains("instantiateBundleStreaming"))
    #expect(source.contains("selectPrimaryBundleID"))
    #expect(source.contains("bootstrappedBundleIDs"))
    #expect(source.contains("bootstrapBundle(this.primaryBundleID"))
    #expect(source.contains("installServerActionListeners()"))
    #expect(source.contains("form[data-server-action=\\\"true\\\"]"))
    #expect(source.contains("data-server-action-button"))
    #expect(source.contains("findServerActionSubmitter(event)"))
    #expect(source.contains("appendFormDataToURL(body, url)"))
    #expect(source.contains("url.searchParams.append(name, value)"))
    #expect(source.contains("event.composedPath"))
    #expect(source.contains("\"X-SwiftWeb-Action-Mode\": \"client\""))
    #expect(source.contains("invalidateServerDocument"))
    #expect(source.contains("mergeServerDocument"))
    #expect(source.contains("protectedClientNodeIDs"))
    #expect(source.contains("documentHydrationIndex"))
    #expect(source.contains("this.manifest?.components"))
    #expect(
      source.contains(
        "addSwiftNodeSubtree(rawValue(component.nodeID), protectedNodeIDs, this, hydrationIndex)"))
    #expect(source.contains("String(rawValue(node.id)) === id"))
    #expect(source.contains("replacedNodeIDs"))
    #expect(source.contains("isDocumentShellElement(current)"))
    #expect(source.contains("this.bootstrapBundle(bundleID, instance)"))
    #expect(source.contains("recordFailure(error)"))
    #expect(source.contains("\"fetchingManifest\""))
    #expect(source.contains("\"instantiatingBundle\""))
    #expect(source.contains("const runtimeWasReady = this.metrics.ready === true"))
    #expect(source.contains("this.publishStatus(runtimeWasReady, \"bundleLoaded\")"))
    #expect(source.contains("IntersectionObserver"))
    #expect(source.contains("const seen = new Set()"))
    #expect(source.contains("this.loadedBundleIDs.has(bundleID)"))
    #expect(source.contains("\"pointerover\""))
    // interactiveDismissDisabled (closedby="none") blocks Esc cross-browser
    // by preventing the modal dialog's cancel default.
    #expect(source.contains("__swuiDismissPolicyBound"))
    #expect(source.contains("addEventListener(\"cancel\""))
    #expect(source.contains("targetInstance = await this.instanceForComponent(componentID)"))
    #expect(
      source.contains(
        "const componentID = payload.swiftWebComponentID || this.componentIDForHandler(payload.handlerID.rawValue)"
      ))
    #expect(source.contains("response.appliesDOMCommandsInRuntime !== true"))
    #expect(source.contains("callRuntime(exportName, payload, instance = this.primaryInstance)"))
    #expect(source.contains("const previousBundles = Array.isArray(this.manifest.bundles)"))
    #expect(source.contains("const previousLoading = this.loading.get(bundleID) || null"))
    #expect(source.contains("this.manifest.bundles = previousBundles"))
    #expect(
      source.contains("restoredBundle.asset = previousAsset ? { ...previousAsset } : previousAsset")
    )
    #expect(source.contains("this.instances.delete(bundleID)"))
    #expect(source.contains("this.swiftRuntimes.delete(bundleID)"))
    #expect(
      source.contains(
        "this.publishStatus(runtimeWasReady, \"bundleLoaded\");\n      this.publishMetrics();"))
    #expect(
      source.contains(
        "this.publishStatus(this.metrics.ready === true, \"bundleLoaded\");\n    this.publishMetrics();"
      ))
    #expect(source.contains("this.recordMetric(\"hmr.clientComponent.complete\""))
    #expect(source.contains("this.publishMetrics();"))
    let runtimeDeclaration = source.range(of: "class SwiftWebWasmRuntime")
    let runtimeStart = source.range(of: "new SwiftWebWasmRuntime")
    #expect(runtimeDeclaration != nil)
    #expect(runtimeStart != nil)
    if let runtimeDeclaration, let runtimeStart {
      #expect(runtimeDeclaration.lowerBound < runtimeStart.lowerBound)
    }
  }

  @Test
  func javaScriptKitRuntimeCandidatesIncludeXcodeSourcePackagesPath() {
    let productsDirectory = URL(
      fileURLWithPath: "/tmp/DerivedData/CounterApp-abc/Build/Products/Debug"
    )

    let candidates = SwiftWebJavaScriptKitRuntimeScript.scriptCandidates(
      currentDirectory: productsDirectory,
      sourceFile: URL(fileURLWithPath: #filePath),
      fileManager: .default
    )

    #expect(
      candidates.map(\.path).contains(
        "/tmp/DerivedData/CounterApp-abc/SourcePackages/checkouts/JavaScriptKit/Plugins/PackageToJS/Templates/runtime.mjs"
      ))
  }

  @Test
  func javaScriptKitRuntimeScriptLoadsFromAvailablePackageCheckout() throws {
    let source = try SwiftWebJavaScriptKitRuntimeScript.load()

    #expect(source.contains("SwiftRuntime"))
    #expect(!source.contains("JavaScriptKit supports only WASI reactor ABI"))
  }

  @Test
  func devHotReloadInjectsReloadWaitScriptAndTokenHeaderWhenEnabled() {
    let html = SwiftWebDevHotReload.inject(
      into: "<html><body><main>Counter</main></body></html>",
      isEnabled: true,
      token: "reload-token"
    )
    let headers = SwiftWebDevHotReload.headers(
      isEnabled: true,
      token: "reload-token"
    )

    #expect(html.contains("<main>Counter</main><script type=\"module\">"))
    #expect(html.contains("const swiftWebDevToken = \"reload-token\";"))
    #expect(html.contains("fetch(swiftWebDevReloadURL.href"))
    #expect(html.contains("__swiftWebDevReload"))
    #expect(html.contains("devStatus"))
    #expect(html.contains("clientBuildStarted"))
    #expect(html.contains("wasmStatus"))
    #expect(html.contains("SwiftWeb dev session changed"))
    #expect(html.contains("SwiftWeb HMR stream failed"))
    #expect(html.contains("SwiftWeb HMR event failed"))
    #expect(html.contains("Client WASM failed"))
    #expect(html.contains("phase === \"error\" || phase === \"failed\""))
    #expect(!html.contains("setInterval"))
    #expect(headers[SwiftWebDevHotReload.reloadTokenHeaderName] == "reload-token")
    #expect(headers[.cacheControl] == "no-cache")
  }
}
