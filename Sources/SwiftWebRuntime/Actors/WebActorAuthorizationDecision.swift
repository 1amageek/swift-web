public enum WebActorAuthorizationDecision: Sendable, Equatable {
    case allow
    case deny(String)
}
