#if SWIFTWEB_ACTORS
public struct WebActorSecurityPolicy: Sendable {
    public var authorization: WebActorAuthorization
    public var activation: WebActorActivationPolicy

    public init(
        authorization: WebActorAuthorization = .trustedOnly,
        activation: WebActorActivationPolicy = .defaults
    ) {
        self.authorization = authorization
        self.activation = activation
    }

    public static let defaults = WebActorSecurityPolicy()

    public static let trustedOnly = WebActorSecurityPolicy(
        authorization: .trustedOnly,
        activation: .defaults
    )

    public static let boundActorsOnly = WebActorSecurityPolicy(
        authorization: .boundActorsOnly,
        activation: .defaults
    )

    public static let allowAll = WebActorSecurityPolicy(
        authorization: .allowAll,
        activation: .defaults
    )
}
#endif
