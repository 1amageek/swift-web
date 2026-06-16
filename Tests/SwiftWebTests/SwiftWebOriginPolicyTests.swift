import HTTPTypes
import NIOCore
@testable import SwiftWeb
import Testing
import Vapor

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
            let trustedRemote = try SocketAddress(ipAddress: "10.0.0.1", port: 443)
            let trustedRequest = Request(application: application, remoteAddress: trustedRemote)
            trustedRequest.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"
            trustedRequest.headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            trustedRequest.headers[HTTPField.Name("X-Forwarded-Host")!] = "example.com"

            let untrustedRemote = try SocketAddress(ipAddress: "10.0.0.2", port: 443)
            let untrustedRequest = Request(application: application, remoteAddress: untrustedRemote)
            untrustedRequest.headers[HTTPField.Name("Host")!] = "127.0.0.1:3000"
            untrustedRequest.headers[HTTPField.Name("X-Forwarded-Proto")!] = "https"
            untrustedRequest.headers[HTTPField.Name("X-Forwarded-Host")!] = "example.com"

            let policy = ForwardedHeadersPolicy.trustedProxies(["10.0.0.1"])
            #expect(OriginPolicy.requestOrigin(for: trustedRequest, forwardedHeaders: policy) == "https://example.com")
            #expect(OriginPolicy.requestOrigin(for: untrustedRequest, forwardedHeaders: policy) == "http://127.0.0.1:3000")
        }
    }

    private func withApplication(
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }
}
