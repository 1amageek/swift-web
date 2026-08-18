#if SWIFTWEB_ACTORS
public struct WebActorSecurityPolicy: Sendable {
    #if SWIFTWEB_LEGACY_ACTORS
    public var legacyAuthorization: WebActorAuthorization
    #endif
    public var activation: WebActorActivationPolicy
    public var authorization: SwiftWebActorAuthorization

    public init(
        activation: WebActorActivationPolicy = .defaults,
        authorization: SwiftWebActorAuthorization = .trustedOnly
    ) {
        self.activation = activation
        self.authorization = authorization
        #if SWIFTWEB_LEGACY_ACTORS
        self.legacyAuthorization = .trustedOnly
        #endif
    }

    #if SWIFTWEB_LEGACY_ACTORS
    @available(*, deprecated, message: "Use the binary SwiftWebActorAuthorization initializer")
    public init(
        authorization: WebActorAuthorization,
        activation: WebActorActivationPolicy = .defaults,
        binaryAuthorization: SwiftWebActorAuthorization = .trustedOnly
    ) {
        self.legacyAuthorization = authorization
        self.activation = activation
        self.authorization = binaryAuthorization
    }
    #endif

    @available(*, deprecated, renamed: "authorization")
    public var binaryAuthorization: SwiftWebActorAuthorization {
        get { authorization }
        set { authorization = newValue }
    }

    public static let defaults = WebActorSecurityPolicy()

    #if SWIFTWEB_LEGACY_ACTORS
    public static let trustedOnly = WebActorSecurityPolicy(
        authorization: WebActorAuthorization.trustedOnly,
        activation: .defaults,
        binaryAuthorization: SwiftWebActorAuthorization.trustedOnly
    )
    #else
    public static let trustedOnly = WebActorSecurityPolicy(
        activation: .defaults,
        authorization: SwiftWebActorAuthorization.trustedOnly
    )
    #endif

    #if SWIFTWEB_LEGACY_ACTORS
    public static let boundActorsOnly = WebActorSecurityPolicy(
        authorization: WebActorAuthorization.boundActorsOnly,
        activation: .defaults,
        binaryAuthorization: SwiftWebActorAuthorization.trustedOnly
    )
    #endif

    #if SWIFTWEB_LEGACY_ACTORS
    public static let allowAll = WebActorSecurityPolicy(
        authorization: WebActorAuthorization.allowAll,
        activation: .defaults,
        binaryAuthorization: SwiftWebActorAuthorization.allowAll
    )
    #else
    public static let allowAll = WebActorSecurityPolicy(
        activation: .defaults,
        authorization: SwiftWebActorAuthorization.allowAll
    )
    #endif
}
#endif
