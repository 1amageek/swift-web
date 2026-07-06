import HTTPTypes

public struct SecurityHeadersPolicy: Sendable {
    public var contentSecurityPolicy: ContentSecurityPolicy?
    public var strictTransportSecurity: StrictTransportSecurityPolicy?
    public var xContentTypeOptions: String?
    public var xFrameOptions: String?
    public var referrerPolicy: String?
    public var permissionsPolicy: String?

    public init(
        contentSecurityPolicy: ContentSecurityPolicy? = nil,
        strictTransportSecurity: StrictTransportSecurityPolicy? = nil,
        xContentTypeOptions: String? = "nosniff",
        xFrameOptions: String? = "DENY",
        referrerPolicy: String? = "strict-origin-when-cross-origin",
        permissionsPolicy: String? = nil
    ) {
        self.contentSecurityPolicy = contentSecurityPolicy
        self.strictTransportSecurity = strictTransportSecurity
        self.xContentTypeOptions = xContentTypeOptions
        self.xFrameOptions = xFrameOptions
        self.referrerPolicy = referrerPolicy
        self.permissionsPolicy = permissionsPolicy
    }

    public static let browserDefaults = SecurityHeadersPolicy()

    public static let strictSelfHosted = SecurityHeadersPolicy(
        contentSecurityPolicy: .selfHosted,
        strictTransportSecurity: .oneYear
    )

    func apply(
        to response: inout Response,
        request: Request,
        context: RequestSecurityContext,
        forwardedHeaders: ForwardedHeadersPolicy
    ) {
        if let contentSecurityPolicy {
            response.headers[contentSecurityPolicy.headerName()] = contentSecurityPolicy.headerValue(nonce: context.cspNonce)
        }
        if let strictTransportSecurity, shouldApplyHSTS(strictTransportSecurity, request: request, forwardedHeaders: forwardedHeaders) {
            response.headers[.strictTransportSecurity] = strictTransportSecurity.headerValue()
        }
        if let xContentTypeOptions {
            response.headers[.xContentTypeOptions] = xContentTypeOptions
        }
        if let xFrameOptions {
            response.headers[HTTPField.Name("X-Frame-Options")!] = xFrameOptions
        }
        if let referrerPolicy {
            response.headers[HTTPField.Name("Referrer-Policy")!] = referrerPolicy
        }
        if let permissionsPolicy {
            response.headers[HTTPField.Name("Permissions-Policy")!] = permissionsPolicy
        }
    }

    private func shouldApplyHSTS(
        _ policy: StrictTransportSecurityPolicy,
        request: Request,
        forwardedHeaders: ForwardedHeadersPolicy
    ) -> Bool {
        guard policy.onlyWhenSecure else {
            return true
        }
        return forwardedHeaders.isSecure(request)
    }
}
