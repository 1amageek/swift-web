import ActorSystemCore

public struct SwiftWebActorAuthorizationRequest: Sendable {
    public let invocation: ActorInvocation
    public let context: SwiftWebActorInvocationContext
    public let origin: ActorInvocationOrigin
    public let isActive: Bool

    public init(
        invocation: ActorInvocation,
        context: SwiftWebActorInvocationContext,
        origin: ActorInvocationOrigin,
        isActive: Bool
    ) {
        self.invocation = invocation
        self.context = context
        self.origin = origin
        self.isActive = isActive
    }
}

public struct SwiftWebActorAuthorization: Sendable {
    private let authorizeValue: @Sendable (
        SwiftWebActorAuthorizationRequest
    ) async throws -> Void

    public init(
        _ authorize: @escaping @Sendable (
            SwiftWebActorAuthorizationRequest
        ) async throws -> Void
    ) {
        self.authorizeValue = authorize
    }

    public func authorize(
        _ request: SwiftWebActorAuthorizationRequest
    ) async throws {
        try await authorizeValue(request)
    }

    public static let trustedOnly = SwiftWebActorAuthorization { request in
        guard case .local = request.origin else {
            throw ActorSystemError.unauthorized
        }
    }

    public static let allowAll = SwiftWebActorAuthorization { _ in }

    public static func authenticatedPrincipalMatchesActorIdentity()
        -> SwiftWebActorAuthorization
    {
        SwiftWebActorAuthorization { request in
            guard let principalID = request.context.principalID,
                  !principalID.isEmpty,
                  request.invocation.recipient.identity == principalID
            else {
                throw ActorSystemError.unauthorized
            }
        }
    }
}
