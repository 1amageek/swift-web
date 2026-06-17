import SwiftHTML
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
        let artifact = renderArtifact(
            environment: .swiftWebCurrent,
            stateStore: stateStore,
            options: options
        )
        SwiftWebDiagnostics.emit(artifact.diagnostics)

        switch runtime {
        case .disabled:
            let html = developmentHooks.injectHTML(artifact.html, securityContext?.cspNonce)
            return Response(
                headers: developmentHooks.htmlHeaders(),
                body: .init(string: html)
            )
        case .wasm(let wasmRuntime):
            let manifest = SwiftWebWasmClientManifestBuilder.manifest(
                from: artifact,
                runtime: wasmRuntime
            )
            let descriptor = SwiftWebClientRuntimeDescriptor(
                mode: .wasm,
                hydrationIndex: BrowserHydrationIndexExporter().export(artifact),
                manifest: manifest,
                wasm: wasmRuntime,
                security: request.clientSecurityDescriptor
            )
            let annotatedHTML = developmentHooks.annotateClientRuntimeHTML(
                artifact.html,
                manifest,
                descriptor.hydrationIndex
            )
            let runtimeHTML = try SwiftWebClientRuntimeHTMLInjector().inject(
                into: annotatedHTML,
                descriptor: descriptor,
                nonce: securityContext?.cspNonce
            )
            let html = developmentHooks.injectHTML(runtimeHTML, securityContext?.cspNonce)
            return Response(
                headers: developmentHooks.htmlHeaders(),
                body: .init(string: html)
            )
        }
    }
}
