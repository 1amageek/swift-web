#if SWIFTWEB_LEGACY_ACTORS
public enum WebActorAuthorizationDecision: Sendable, Equatable {
    case allow
    case deny(String)
}
#endif
