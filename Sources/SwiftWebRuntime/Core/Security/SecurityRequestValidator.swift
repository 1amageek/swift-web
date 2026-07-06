import HTTPTypes

public enum SecurityRequestValidator {
    public static func validateStateChangingRequest(
        _ request: Request,
        suppliedCSRFToken: String? = nil
    ) throws {
        try validateOrigin(request)
        try validateCSRF(request, suppliedCSRFToken: suppliedCSRFToken)
    }

    static func validateOrigin(_ request: Request) throws {
        let security = request.application.securityConfiguration
        guard security.csrf.protects(request.method) else {
            return
        }
        guard security.origin.allowsRequestOrigin(request, forwardedHeaders: security.forwardedHeaders) else {
            throw Abort(.forbidden, reason: originRejectionReason(
                request,
                forwardedHeaders: security.forwardedHeaders
            ))
        }
    }

    private static func originRejectionReason(
        _ request: Request,
        forwardedHeaders: ForwardedHeadersPolicy
    ) -> String {
        let origin = request.headers[.origin] ?? "none"
        let referrer = request.headers[HTTPField.Name("Referer")!] ?? "none"
        let host = request.headers[HTTPField.Name("Host")!] ?? "none"
        let targetOrigin = OriginPolicy.requestOrigin(
            for: request,
            forwardedHeaders: forwardedHeaders
        ) ?? "none"
        return "Request origin is not allowed (origin: \(origin), referrer: \(referrer), target: \(targetOrigin), host: \(host))"
    }

    static func validateCSRF(
        _ request: Request,
        suppliedCSRFToken: String? = nil
    ) throws {
        let security = request.application.securityConfiguration
        guard security.csrf.protects(request.method) else {
            return
        }
        guard security.csrf.isEnabled else {
            return
        }
        let expectedToken = request.cookies[security.csrf.cookieName]
        let headerToken = request.headers[security.csrf.headerName]
        let actualToken = suppliedCSRFToken ?? headerToken
        guard let expectedToken,
              let actualToken,
              expectedToken == actualToken,
              SecurityConfiguration.isValidToken(actualToken) else {
            throw Abort(.forbidden, reason: "CSRF token is missing or invalid")
        }
    }

    static func csrfToken(from request: Request, source: CSRFTokenSource) async throws -> String? {
        let security = request.application.securityConfiguration
        guard security.csrf.isEnabled, security.csrf.protects(request.method) else {
            return nil
        }
        if source.allowsHeader, let token = request.headers[security.csrf.headerName] {
            return token
        }
        guard source.allowsFormField else {
            return nil
        }
        let payload = try await request.content.decode(CSRFTokenPayload.self)
        return payload.value(for: security.csrf.formFieldName)
    }
}

private struct CSRFTokenPayload: Codable {
    private let fields: [String: String]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: DynamicCodingKey.self)
        var fields: [String: String] = [:]
        for key in container.allKeys {
            fields[key.stringValue] = try container.decodeIfPresent(String.self, forKey: key)
        }
        self.fields = fields
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: DynamicCodingKey.self)
        for (key, value) in fields {
            try container.encode(value, forKey: DynamicCodingKey(stringValue: key))
        }
    }

    func value(for name: String) -> String? {
        fields[name]
    }
}

private struct DynamicCodingKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
