import Foundation
import Vapor

public struct SecurityConfiguration: Sendable {
    public var cors: CORSPolicy
    public var csrf: CSRFPolicy
    public var origin: OriginPolicy
    public var redirects: RedirectPolicy
    public var headers: SecurityHeadersPolicy
    public var forwardedHeaders: ForwardedHeadersPolicy

    public init(
        cors: CORSPolicy = .sameOrigin,
        csrf: CSRFPolicy = .enabled,
        origin: OriginPolicy = .sameOrigin,
        redirects: RedirectPolicy = .sameOrigin,
        headers: SecurityHeadersPolicy = .browserDefaults,
        forwardedHeaders: ForwardedHeadersPolicy = .ignore
    ) {
        self.cors = cors
        self.csrf = csrf
        self.origin = origin
        self.redirects = redirects
        self.headers = headers
        self.forwardedHeaders = forwardedHeaders
    }

    public static let defaults = SecurityConfiguration()

    public static let strictSelfHosted = SecurityConfiguration(
        headers: .strictSelfHosted
    )

    func installMiddleware(on middlewares: inout Middlewares) {
        if let corsMiddleware = cors.middleware(
            forwardedHeaders: forwardedHeaders,
            csrfHeaderName: csrf.isEnabled ? csrf.headerName : nil
        ) {
            middlewares.use(corsMiddleware)
        }
        middlewares.use(SecurityMiddleware(configuration: self))
    }

    func makeRequestContext(for request: Request) -> RequestSecurityContext {
        let csrfContext = makeCSRFContext(for: request)
        let nonce = headers.contentSecurityPolicy == nil ? nil : Self.randomToken(byteCount: 16)
        return RequestSecurityContext(
            csrfToken: csrfContext.token,
            csrfFieldName: csrf.formFieldName,
            cspNonce: nonce,
            shouldSetCSRFCookie: csrfContext.shouldSetCookie
        )
    }

    private func makeCSRFContext(for request: Request) -> (token: String?, shouldSetCookie: Bool) {
        guard csrf.isEnabled else {
            return (nil, false)
        }
        if let token = request.cookies[csrf.cookieName]?.string, Self.isValidToken(token) {
            return (token, false)
        }
        return (Self.randomToken(byteCount: csrf.tokenByteCount), true)
    }

    static func isValidToken(_ token: String) -> Bool {
        !token.isEmpty && token.allSatisfy { character in
            character.isLetter || character.isNumber || character == "-" || character == "_"
        }
    }

    static func randomToken(byteCount: Int) -> String {
        var generator = SystemRandomNumberGenerator()
        let bytes = (0..<byteCount).map { _ in UInt8.random(in: UInt8.min...UInt8.max, using: &generator) }
        let token = Data(bytes).base64EncodedString()
        return token
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}

private struct SecurityConfigurationStorageKey: StorageKey {
    typealias Value = SecurityConfiguration
}

extension Application {
    var securityConfiguration: SecurityConfiguration {
        get {
            storage[SecurityConfigurationStorageKey.self] ?? .defaults
        }
        set {
            storage[SecurityConfigurationStorageKey.self] = newValue
        }
    }
}
