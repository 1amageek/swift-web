#if SWIFTWEB_ACTORS
/// Declares where a virtual actor's identity key comes from, and which
/// authorization rule guards invocations addressed to it.
///
/// The scope algebra has three primitives:
///
/// - ``derived(_:_:)``: the server derives the key from the trusted
///   invocation context. Authorization is identity-match and automatic —
///   an external caller cannot address another principal's actor because
///   the key is never taken from the request.
/// - ``addressed(authorization:)``: the caller names the key (an entity ID
///   such as a room or document). An authorization policy is required by
///   the type system; an open endpoint must be declared explicitly with
///   ``WebActorAuthorization/allowAll``.
/// - ``transient``: the actor has no durable identity and lives only for
///   the addressing connection.
///
/// Scopes compose with `+`: `.user + .addressed(authorization: policy)`
/// produces identities like `contract:user:<uid>:<entity>` with the
/// segment rules combined (every segment must authorize).
public struct ActorScope: Sendable {
    /// One identity segment and the rule that authorizes it.
    enum Segment: Sendable {
        /// Key derived on the server from the invocation context.
        /// `label` names the segment inside the identity string;
        /// `extract` fails when the context cannot supply the key.
        case derived(label: String, extract: @Sendable (WebActorInvocationContext) throws -> String)

        /// Key supplied by the caller, guarded by an explicit policy.
        case addressed(authorization: WebActorAuthorization)
    }

    let segments: [Segment]
    public let isTransient: Bool

    private init(segments: [Segment], isTransient: Bool) {
        self.segments = segments
        self.isTransient = isTransient
    }

    // MARK: Primitives

    /// A server-derived identity segment. The key comes from the trusted
    /// invocation context, never from the request payload.
    public static func derived(
        _ label: String,
        _ extract: @escaping @Sendable (WebActorInvocationContext) throws -> String
    ) -> ActorScope {
        ActorScope(segments: [.derived(label: label, extract: extract)], isTransient: false)
    }

    /// A caller-addressed identity segment guarded by an explicit policy.
    public static func addressed(authorization: WebActorAuthorization) -> ActorScope {
        ActorScope(segments: [.addressed(authorization: authorization)], isTransient: false)
    }

    /// No durable identity: the actor lives and dies with the connection.
    public static let transient = ActorScope(segments: [], isTransient: true)

    // MARK: Presets

    /// One actor per application: a constant identity key.
    public static let application = ActorScope.derived("app") { _ in "app" }

    /// One actor per authenticated principal. Derivation fails without an
    /// authenticated principal; there is no anonymous fallback.
    public static let user = ActorScope.derived("user") { context in
        guard let principalID = context.principalID, !principalID.isEmpty else {
            throw ActorScopeError.missingContextValue(segment: "user", field: "principalID")
        }
        return principalID
    }

    /// One actor per tenant (organization / workspace) claim.
    public static let tenant = ActorScope.derived("tenant") { context in
        guard let tenantID = context.tenantID, !tenantID.isEmpty else {
            throw ActorScopeError.missingContextValue(segment: "tenant", field: "tenantID")
        }
        return tenantID
    }

    /// One actor per cookie session.
    public static let session = ActorScope.derived("session") { context in
        guard let sessionID = context.sessionID, !sessionID.isEmpty else {
            throw ActorScopeError.missingContextValue(segment: "session", field: "sessionID")
        }
        return sessionID
    }

    // MARK: Composition

    /// Concatenates identity segments; every segment's rule must authorize.
    /// Composing with ``transient`` is a configuration error surfaced by
    /// ``ActorGroup`` validation, not silently ignored.
    public static func + (lhs: ActorScope, rhs: ActorScope) -> ActorScope {
        ActorScope(
            segments: lhs.segments + rhs.segments,
            isTransient: lhs.isTransient || rhs.isTransient
        )
    }

    // MARK: Identity derivation

    /// Derives the identity name for the derived segments of this scope.
    /// Addressed segments contribute the caller-supplied remainder and are
    /// validated by ``authorization()``.
    func derivedNamePrefix(context: WebActorInvocationContext) throws -> [String] {
        var components: [String] = []
        for segment in segments {
            switch segment {
            case .derived(let label, let extract):
                components.append(label)
                components.append(try extract(context))
            case .addressed:
                return components
            }
        }
        return components
    }

    /// The invocation authorization implied by this scope: derived segments
    /// require the recipient name to start with the context-derived prefix,
    /// and addressed segments apply their explicit policy.
    public func authorization() -> WebActorAuthorization {
        let scope = self
        return WebActorAuthorization { request in
            guard request.context.isExternal else {
                return .allow
            }
            let prefix: [String]
            do {
                prefix = try scope.derivedNamePrefix(context: request.context)
            } catch {
                return .deny("Actor scope derivation failed: \(error)")
            }
            let expectedPrefix = prefix.joined(separator: ":")
            if !expectedPrefix.isEmpty {
                guard let name = request.recipient.name else {
                    return .deny("Actor recipient has no scoped name")
                }
                guard name == expectedPrefix || name.hasPrefix(expectedPrefix + ":") else {
                    return .deny("Actor recipient is outside the caller's derived scope")
                }
            }
            for segment in scope.segments {
                if case .addressed(let authorization) = segment {
                    let decision = await authorization.authorize(request)
                    guard case .allow = decision else {
                        return decision
                    }
                }
            }
            return .allow
        }
    }
}

/// Errors raised while deriving an actor identity from a scope.
public enum ActorScopeError: Error, Sendable, Equatable {
    /// The invocation context could not supply the value a derived segment
    /// requires (for example `.user` without an authenticated principal).
    case missingContextValue(segment: String, field: String)
}
#endif
