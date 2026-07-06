import HTTPTypes

public struct CORSPolicy: Sendable {
    public var isEnabled: Bool
    public var origin: OriginPolicy
    public var allowedMethods: [HTTPRequest.Method]
    public var allowedHeaders: [HTTPField.Name]
    public var exposedHeaders: [HTTPField.Name]
    public var allowsCredentials: Bool
    public var cacheExpiration: Int?

    public init(
        isEnabled: Bool = true,
        origin: OriginPolicy = .sameOrigin,
        allowedMethods: [HTTPRequest.Method] = [.get, .head, .post, .put, .patch, .delete, .options],
        allowedHeaders: [HTTPField.Name] = [
            .accept,
            .authorization,
            .contentType,
            .origin,
            HTTPField.Name("X-Requested-With")!,
            HTTPField.Name("X-SwiftWeb-Action-Mode")!,
            HTTPField.Name("X-CSRF-Token")!,
            HTTPField.Name("X-SwiftWeb-Invalidation")!,
        ],
        exposedHeaders: [HTTPField.Name] = [],
        allowsCredentials: Bool = false,
        cacheExpiration: Int? = 600
    ) {
        self.isEnabled = isEnabled
        self.origin = origin
        self.allowedMethods = allowedMethods
        self.allowedHeaders = allowedHeaders
        self.exposedHeaders = exposedHeaders
        self.allowsCredentials = allowsCredentials
        self.cacheExpiration = cacheExpiration
    }

    public static let disabled = CORSPolicy(isEnabled: false)

    public static let sameOrigin = CORSPolicy()

    func middleware(
        forwardedHeaders: ForwardedHeadersPolicy,
        csrfHeaderName: HTTPField.Name?
    ) -> CORSMiddleware? {
        guard isEnabled else {
            return nil
        }
        var effectiveAllowedHeaders = allowedHeaders
        if let csrfHeaderName, !effectiveAllowedHeaders.contains(csrfHeaderName) {
            effectiveAllowedHeaders.append(csrfHeaderName)
        }
        return CORSMiddleware(
            originPolicy: origin,
            forwardedHeaders: forwardedHeaders,
            allowedMethods: allowedMethods.map { "\($0)" }.joined(separator: ", "),
            allowedHeaders: effectiveAllowedHeaders.map(\.canonicalName).joined(separator: ", "),
            exposedHeaders: exposedHeaders.isEmpty
                ? nil
                : exposedHeaders.map(\.canonicalName).joined(separator: ", "),
            allowsCredentials: allowsCredentials,
            cacheExpiration: cacheExpiration
        )
    }
}
