import HTTPTypes
import Testing
@testable import SwiftWeb
@testable import SwiftWebBrowserRuntime
@testable import SwiftWebCore

@Suite
struct SecurityRenderingTests {
    @Test
    func runtimeDescriptorCarriesCSRFAndInjectorAddsNonce() throws {
        let runtime = SwiftWebWasmClientRuntime(
            manifestPath: "/assets/swift-web-client.json",
            runtimeAssetPath: "/assets/runtime.wasm"
        )
        let descriptor = SwiftWebClientRuntimeDescriptor(
            mode: .wasm,
            hydrationIndex: .empty,
            wasm: runtime,
            security: ClientSecurityDescriptor(
                csrfToken: "token",
                csrfHeaderName: "X-CSRF-Token",
                csrfFieldName: "_csrf"
            )
        )

        let html = try SwiftWebClientRuntimeHTMLInjector().inject(
            into: "<html><head></head><body><main>Counter</main></body></html>",
            descriptor: descriptor,
            nonce: "nonce"
        )

        #expect(html.contains("nonce=\"nonce\""))
        #expect(html.contains("\"csrfToken\":\"token\""))
        #expect(SwiftWebWasmRuntimeHostScript.source.contains("...this.csrfHeaders()"))
        #expect(SwiftWebWasmRuntimeHostScript.source.contains("parent.removeChild(node);"))
    }

    @Test
    func actionMetadataFieldsRenderCSRFTokenFromRequestContext() async throws {
        try await withTestApplication { application in
            let request = Request(application: application)
            let context = RequestSecurityContext(csrfToken: "token", csrfFieldName: "_csrf")
            let values = RequestValues(
                request: request,
                params: NoParams(),
                searchParams: NoSearchParams(),
                security: context
            )
            let reference = ActionReference<NoActionInput, ActionResult>(
                path: "/counter/increment",
                httpMethod: .post,
                inputType: "SwiftWeb.NoActionInput",
                outputType: "SwiftWeb.ActionResult"
            )

            let rendered = await RequestContext.withValue(values) {
                ActionMetadataFields(reference).render()
            }

            #expect(rendered.contains("name=\"_csrf\" value=\"token\""))
        }
    }

    private func withTestApplication(
        _ body: (TestWebApplication) async throws -> Void
    ) async throws {
        try await body(TestWebApplication())
    }
}
