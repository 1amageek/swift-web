/// The per-request security context (CSRF token / CSP nonce), stored on the request.
public struct RequestSecurityContext: Sendable, Equatable {
    public let csrfToken: String?
    public let csrfFieldName: String?
    public let cspNonce: String?

    public let shouldSetCSRFCookie: Bool

    public init(
        csrfToken: String? = nil,
        csrfFieldName: String? = nil,
        cspNonce: String? = nil,
        shouldSetCSRFCookie: Bool = false
    ) {
        self.csrfToken = csrfToken
        self.csrfFieldName = csrfFieldName
        self.cspNonce = cspNonce
        self.shouldSetCSRFCookie = shouldSetCSRFCookie
    }
}
