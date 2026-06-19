import HTTPTypes
import NIOCore
@testable import SwiftWeb
@testable import SwiftWebCore
import Testing
import Vapor
import VaporTesting

@Suite
struct SecurityTests {
    @Test
    func securityMiddlewareSetsCSRFCookieAndBrowserHeaders() async throws {
        try await withSecurityApplication { application in
            application.get("page") { _ async throws -> String in
                "ok"
            }

            let response = try await application.testing().sendRequest(.get, "/page", hostname: "example.com")

            #expect(response.status == .ok)
            #expect(response.headers[.xContentTypeOptions] == "nosniff")
            #expect(response.headers[.xFrameOptions] == "DENY")
            #expect(response.headers[HTTPField.Name("Referrer-Policy")!] == "strict-origin-when-cross-origin")
            let setCookie = try csrfSetCookie(from: response)
            #expect(setCookie.contains("csrf_token="))
            #expect(setCookie.contains("HttpOnly"))
            #expect(setCookie.contains("SameSite=Lax"))
        }
    }

    @Test
    func corsPreflightAllowsSameOriginOnlyByDefault() async throws {
        try await withSecurityApplication { application in
            RouteAction.post(SecurityFormAction.self, on: application, path: "/submit")

            var sameOriginHeaders: HTTPFields = [:]
            sameOriginHeaders[.origin] = "http://example.com"
            sameOriginHeaders[.accessControlRequestMethod] = "POST"
            let sameOrigin = try await application.testing().sendRequest(
                .options,
                "/submit",
                hostname: "example.com",
                headers: sameOriginHeaders
            )

            var externalHeaders: HTTPFields = [:]
            externalHeaders[.origin] = "https://evil.example"
            externalHeaders[.accessControlRequestMethod] = "POST"
            let external = try await application.testing().sendRequest(
                .options,
                "/submit",
                hostname: "example.com",
                headers: externalHeaders
            )

            #expect(sameOrigin.headers[.accessControlAllowOrigin] == "http://example.com")
            #expect(external.headers[.accessControlAllowOrigin] == nil)
        }
    }

    @Test
    func corsPreflightIncludesCustomCSRFHeader() async throws {
        var configuration = SecurityConfiguration.defaults
        configuration.csrf = CSRFPolicy(headerName: HTTPField.Name("X-App-CSRF")!)

        try await withSecurityApplication(configuration) { application in
            RouteAction.post(SecurityFormAction.self, on: application, path: "/submit")

            var headers: HTTPFields = [:]
            headers[.origin] = "http://example.com"
            headers[.accessControlRequestMethod] = "POST"
            headers[.accessControlRequestHeaders] = "X-App-CSRF"
            let response = try await application.testing().sendRequest(
                .options,
                "/submit",
                hostname: "example.com",
                headers: headers
            )

            #expect(response.headers[.accessControlAllowOrigin] == "http://example.com")
            let allowedHeaders = response.headers[values: .accessControlAllowHeaders]
                .joined(separator: ",")
                .lowercased()
            #expect(allowedHeaders.contains("x-app-csrf"))
        }
    }

    @Test
    func formActionRequiresValidCSRFToken() async throws {
        try await withSecurityApplication { application in
            application.get("page") { _ async throws -> String in
                "token-source"
            }
            RouteAction.post(SecurityFormAction.self, on: application, path: "/submit")

            let page = try await application.testing().sendRequest(.get, "/page", hostname: "example.com")
            let token = try csrfToken(from: page)

            let missingHeaders = formHeaders(origin: "http://example.com")
            let missing = try await application.testing().sendRequest(
                .post,
                "/submit",
                hostname: "example.com",
                headers: missingHeaders,
                body: buffer("value=missing")
            )

            var validHeaders = formHeaders(origin: "http://example.com")
            validHeaders[.cookie] = "csrf_token=\(token)"
            let valid = try await application.testing().sendRequest(
                .post,
                "/submit",
                hostname: "example.com",
                headers: validHeaders,
                body: buffer("_csrf=\(token)&value=accepted")
            )

            #expect(missing.status == .forbidden)
            #expect(valid.status == .ok)
            #expect(String(buffer: valid.body) == "accepted")
        }
    }

    @Test
    func formActionRejectsCrossOriginEvenWithValidCSRFToken() async throws {
        try await withSecurityApplication { application in
            application.get("page") { _ async throws -> String in
                "token-source"
            }
            RouteAction.post(SecurityFormAction.self, on: application, path: "/submit")

            let page = try await application.testing().sendRequest(.get, "/page", hostname: "example.com")
            let token = try csrfToken(from: page)
            var headers = formHeaders(origin: "https://evil.example")
            headers[.cookie] = "csrf_token=\(token)"

            let response = try await application.testing().sendRequest(
                .post,
                "/submit",
                hostname: "example.com",
                headers: headers,
                body: buffer("_csrf=\(token)&value=rejected")
            )

            #expect(response.status == .forbidden)
        }
    }

    @Test
    func formActionRejectsCrossOriginBeforeDecodingBody() async throws {
        try await withSecurityApplication { application in
            RouteAction.post(SecurityFormAction.self, on: application, path: "/submit")

            var headers: HTTPFields = [:]
            headers[.origin] = "https://evil.example"
            headers[.contentType] = "application/json"
            let response = try await application.testing().sendRequest(
                .post,
                "/submit",
                hostname: "example.com",
                headers: headers,
                body: buffer("{")
            )

            #expect(response.status == .forbidden)
        }
    }

    @Test
    func actionGatewayRejectsCrossOriginBeforeDecodingBody() async throws {
        try await withSecurityApplication { application in
            ActionGateway.register(on: application)

            var headers: HTTPFields = [:]
            headers[.origin] = "https://evil.example"
            headers[.contentType] = "application/json"
            let response = try await application.testing().sendRequest(
                .post,
                "/_swiftweb/actions/CounterService/increment",
                hostname: "example.com",
                headers: headers,
                body: buffer("{")
            )

            #expect(response.status == .forbidden)
        }
    }

    @Test
    func uploadActionRequiresHeaderCSRFTokenWithoutReadingStreamBodyToken() async throws {
        try await withSecurityApplication { application in
            application.get("page") { _ async throws -> String in
                "token-source"
            }
            UploadRoute.post(SecurityUploadAction.self, on: application, path: "/upload", body: .stream)

            let page = try await application.testing().sendRequest(.get, "/page", hostname: "example.com")
            let token = try csrfToken(from: page)

            var bodyTokenHeaders = formHeaders(origin: "http://example.com")
            bodyTokenHeaders[.cookie] = "csrf_token=\(token)"
            let bodyTokenOnly = try await application.testing().sendRequest(
                .post,
                "/upload",
                hostname: "example.com",
                headers: bodyTokenHeaders,
                body: buffer("_csrf=\(token)&value=body-token")
            )

            var headerTokenHeaders = formHeaders(origin: "http://example.com")
            headerTokenHeaders[.cookie] = "csrf_token=\(token)"
            headerTokenHeaders[HTTPField.Name("X-CSRF-Token")!] = token
            let headerToken = try await application.testing().sendRequest(
                .post,
                "/upload",
                hostname: "example.com",
                headers: headerTokenHeaders,
                body: buffer("value=header-token")
            )

            #expect(bodyTokenOnly.status == .forbidden)
            #expect(headerToken.status == .ok)
            #expect(String(buffer: headerToken.body) == "header-token")
        }
    }

    @Test
    func hstsTrustsForwardedProtoOnlyWhenConfigured() async throws {
        var ignored = SecurityConfiguration.strictSelfHosted
        ignored.forwardedHeaders = .ignore
        try await withSecurityApplication(ignored) { application in
            application.get("page") { _ async throws -> String in
                "ok"
            }

            var headers: HTTPFields = [:]
            headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            let response = try await application.testing().sendRequest(
                .get,
                "/page",
                hostname: "example.com",
                headers: headers
            )

            #expect(response.headers[.strictTransportSecurity] == nil)
        }

        var trusted = SecurityConfiguration.strictSelfHosted
        trusted.forwardedHeaders = .trust
        try await withSecurityApplication(trusted) { application in
            application.get("page") { _ async throws -> String in
                "ok"
            }

            var headers: HTTPFields = [:]
            headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            let response = try await application.testing().sendRequest(
                .get,
                "/page",
                hostname: "example.com",
                headers: headers
            )

            #expect(response.headers[.strictTransportSecurity] == "max-age=31536000; includeSubDomains")
        }
    }

    @Test
    func actionResultDoesNotRedirectToExternalReferrer() async throws {
        try await withSecurityApplication { application in
            application.get("invalidate") { request async throws -> Response in
                try await ActionResult.invalidate(.page).encodeResponse(for: request)
            }
            application.get("redirect") { request async throws -> Response in
                try await ActionResult.redirect("https://evil.example/path").encodeResponse(for: request)
            }

            var referrerHeaders: HTTPFields = [:]
            referrerHeaders[HTTPField.Name("Referer")!] = "https://evil.example/after-action"
            let invalidation = try await application.testing().sendRequest(
                .get,
                "/invalidate",
                hostname: "example.com",
                headers: referrerHeaders
            )
            let redirect = try await application.testing().sendRequest(
                .get,
                "/redirect",
                hostname: "example.com"
            )

            #expect(invalidation.status == .seeOther)
            #expect(invalidation.headers[HTTPField.Name("Location")!] == "/")
            #expect(redirect.status == .forbidden)
        }
    }

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
        try await withSecurityApplication { application in
            let request = Request(application: application)
            let context = RequestSecurityContext(csrfToken: "token", csrfFieldName: "_csrf")
            let values = RequestValues(
                request: request,
                params: NoParams(),
                searchParams: NoSearchParams(),
                security: context
            )
            let reference = ActionReference<NoActionInput, ActionResult>(
                actorID: "CounterService",
                actorName: "CounterService",
                methodName: "increment",
                targetIdentifier: "increment(_:context:)",
                inputType: "SwiftWeb.NoActionInput",
                outputType: "SwiftWeb.ActionResult",
                capabilityToken: "capability"
            )

            let rendered = await RequestContext.withValue(values) {
                ActionMetadataFields(reference).render()
            }

            #expect(rendered.contains("name=\"_csrf\" value=\"token\""))
        }
    }

    private func withSecurityApplication(
        _ configuration: SecurityConfiguration = .defaults,
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        application.securityConfiguration = configuration
        var middlewares = Middlewares()
        application.securityConfiguration.installMiddleware(on: &middlewares)
        middlewares.use(ErrorMiddleware.default(environment: application.environment))
        application.middleware = middlewares
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }

    private func formHeaders(origin: String) -> HTTPFields {
        var headers: HTTPFields = [:]
        headers[.origin] = origin
        headers[.contentType] = "application/x-www-form-urlencoded"
        return headers
    }

    private func buffer(_ string: String) -> ByteBuffer {
        ByteBufferAllocator().buffer(string: string)
    }

    private func csrfSetCookie(from response: TestingHTTPResponse) throws -> String {
        guard let setCookie = response.headers[values: .setCookie].first else {
            throw SecurityTestError.missingCSRFCookie
        }
        return setCookie
    }

    private func csrfToken(from response: TestingHTTPResponse) throws -> String {
        let setCookie = try csrfSetCookie(from: response)
        guard let cookieValue = setCookie.split(separator: ";").first,
              let token = cookieValue.split(separator: "=", maxSplits: 1).last else {
            throw SecurityTestError.missingCSRFCookie
        }
        return String(token)
    }
}

private struct SecurityFormAction: FormAction {
    struct Input: Decodable, Sendable {
        let value: String
    }

    func call(_ context: ActionContext<NoParams, Input>) async throws -> ActionResult {
        .text(context.input.value)
    }
}

private struct SecurityUploadAction: UploadAction {
    struct Input: Decodable, Sendable {
        let value: String
    }

    func upload(_ context: UploadContext<NoParams, Input>) async throws -> ActionResult {
        .text(context.input.value)
    }
}

private enum SecurityTestError: Error {
    case missingCSRFCookie
}
