public struct WebActorAuthorization: Sendable {
    private let authorizeValue: @Sendable (WebActorAuthorizationRequest) async -> WebActorAuthorizationDecision

    public init(
        _ authorize: @escaping @Sendable (WebActorAuthorizationRequest) async -> WebActorAuthorizationDecision
    ) {
        self.authorizeValue = authorize
    }

    public func authorize(_ request: WebActorAuthorizationRequest) async -> WebActorAuthorizationDecision {
        await authorizeValue(request)
    }

    /// Allows direct in-process calls and concrete actors already registered by
    /// the server, while requiring explicit app authorization for virtual
    /// `ActorGroup` actors. This policy does not prove caller ownership; use an
    /// app authorizer when actor IDs include user or tenant identity.
    public static let boundActorsOnly = WebActorAuthorization { request in
        guard request.context.isExternal else {
            return .allow
        }
        guard request.isRegistered, !request.isVirtualActor else {
            return .deny("External virtual actor invocation requires an explicit actor authorizer")
        }
        return .allow
    }

    public static let trustedOnly = WebActorAuthorization { request in
        request.context.isExternal
            ? .deny("External actor invocation is disabled")
            : .allow
    }

    public static let allowAll = WebActorAuthorization { _ in .allow }

    public static func authenticatedPrincipalMatchesActorName() -> WebActorAuthorization {
        WebActorAuthorization { request in
            guard !request.context.isExternal else {
                guard let principalID = request.context.principalID, !principalID.isEmpty else {
                    return .deny("Actor invocation requires an authenticated principal")
                }
                guard request.recipient.name == principalID else {
                    return .deny("Actor recipient is not owned by the authenticated principal")
                }
                return .allow
            }
            return .allow
        }
    }
}
