import HTTPTypes
@testable import SwiftWeb
@testable import SwiftWebCore
import Testing

@Suite
struct OriginPolicyTests {
    @Test
    func requestOriginUsesHostHeader() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            request.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"

            #expect(OriginPolicy.requestOrigin(for: request) == "http://127.0.0.1:3000")
        }
    }

    @Test
    func requestOriginFallsBackToServerConfigurationWhenHostHeaderIsMissing() async throws {
        try await withApplication { application in
            application.serverConfiguration.hostname = "127.0.0.1"
            application.serverConfiguration.port = 3000
            let request = Request(application: application)

            #expect(OriginPolicy.requestOrigin(for: request) == "http://127.0.0.1:3000")
            #expect(OriginPolicy.sameOrigin.allows(origin: "http://127.0.0.1:3000", for: request))
        }
    }

    @Test
    func requestOriginIgnoresForwardedHeadersByDefault() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            request.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"
            request.headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            request.headers[HTTPField.Name("X-Forwarded-Host")!] = "example.com"

            #expect(OriginPolicy.requestOrigin(for: request) == "http://127.0.0.1:3000")
        }
    }

    @Test
    func requestOriginUsesForwardedHeadersWhenTrusted() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            request.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"
            request.headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            request.headers[HTTPField.Name("X-Forwarded-Host")!] = "example.com"

            #expect(OriginPolicy.requestOrigin(for: request, forwardedHeaders: .trust) == "https://example.com")
        }
    }

    @Test
    func requestOriginUsesForwardedHeadersOnlyForTrustedProxy() async throws {
        try await withApplication { application in
            let trustedRequest = Request(application: application, remoteAddress: "10.0.0.1")
            trustedRequest.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"
            trustedRequest.headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            trustedRequest.headers[HTTPField.Name("X-Forwarded-Host")!] = "example.com"

            let untrustedRequest = Request(application: application, remoteAddress: "10.0.0.2")
            untrustedRequest.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"
            untrustedRequest.headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            untrustedRequest.headers[HTTPField.Name("X-Forwarded-Host")!] = "example.com"

            let policy = ForwardedHeadersPolicy.trustedProxies(["10.0.0.1"])
            #expect(OriginPolicy.requestOrigin(for: trustedRequest, forwardedHeaders: policy) == "https://example.com")
            #expect(OriginPolicy.requestOrigin(for: untrustedRequest, forwardedHeaders: policy) == "http://127.0.0.1:3000")
        }
    }

    private func withApplication(
        _ body: (TestWebApplication) async throws -> Void
    ) async throws {
        try await body(TestWebApplication())
    }
}
