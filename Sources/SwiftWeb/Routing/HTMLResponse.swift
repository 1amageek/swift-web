import SwiftHTML
import SwiftWebStyle
import Vapor

extension HTML {
    public func encodePageResponse(for request: Request, metadata: PageMetadata) async throws -> Response {
        try await PageDocument(metadata: metadata) {
            self
        }
        .encodeResponse(for: request)
    }

    public func encodePageResponse(
        for request: Request,
        metadata: PageMetadata,
        cache: CachePolicy
    ) async throws -> Response {
        let response = try await encodePageResponse(for: request, metadata: metadata)
        return response.cache(cache)
    }

    public func encodeResponse(for request: Request) async throws -> Response {
        let stateStore = StateStore()
        let baseOptions = SwiftWebRenderOptions.current
        let runtime = request.application.swiftWebClientRuntime
        let securityContext = request.securityContext
        let developmentHooks = await SwiftWebDevelopmentSupport.shared.currentHooks()

        let options = baseOptions
            .withClientHandlerClosures(runtime.capturesClientHandlerClosures)
            .withBrowserHydrationMarkers(runtime.emitsBrowserHydrationMarkers)
        let styleRegistry = StyleRegistry()
        let artifact = StyleRegistry.withCurrent(styleRegistry) {
            renderArtifact(
                environment: .swiftWebCurrent,
                stateStore: stateStore,
                options: options
            )
        }
        SwiftWebDiagnostics.emit(artifact.diagnostics)
        let nonce = securityContext?.cspNonce
        let renderedHTML = artifact.html
            .replacingOccurrences(of: "<!--swui-base-->", with: SwiftWebHeadAssets.baseStyle(from: styleRegistry, nonce: nonce))
            .replacingOccurrences(of: "<!--swui-atomic-->", with: SwiftWebHeadAssets.atomicStyle(from: styleRegistry, nonce: nonce))
            .replacingOccurrences(of: "<!--swui-head-scripts-->", with: SwiftWebHeadAssets.scripts(from: styleRegistry, nonce: nonce))

        switch runtime {
        case .disabled:
            let html = developmentHooks.injectHTML(renderedHTML, nonce)
            return Response(
                headers: developmentHooks.htmlHeaders(),
                body: .init(string: html)
            )
        case .wasm(let wasmRuntime):
            let fullHydrationIndex = BrowserHydrationIndexExporter().export(artifact)
            let clientHydrationIndex = SwiftWebClientHydrationIndexPruner.prune(fullHydrationIndex)
            let manifest = SwiftWebWasmClientManifestBuilder.manifest(
                from: artifact,
                runtime: wasmRuntime
            )
            let descriptor = SwiftWebClientRuntimeDescriptor(
                mode: .wasm,
                hydrationIndex: clientHydrationIndex,
                manifest: manifest,
                wasm: wasmRuntime,
                security: request.clientSecurityDescriptor
            )
            let annotatedHTML = developmentHooks.annotateClientRuntimeHTML(
                renderedHTML,
                manifest,
                clientHydrationIndex
            )
            let runtimeHTML = try SwiftWebClientRuntimeHTMLInjector().inject(
                into: annotatedHTML,
                descriptor: descriptor,
                nonce: nonce
            )
            let html = developmentHooks.injectHTML(runtimeHTML, nonce)
            return Response(
                headers: developmentHooks.htmlHeaders(),
                body: .init(string: html)
            )
        }
    }
}
