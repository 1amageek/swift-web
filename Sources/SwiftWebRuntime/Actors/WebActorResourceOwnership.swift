#if SWIFTWEB_LEGACY_ACTORS
public enum WebActorResourceOwnership: Equatable, Sendable {
    case owned
    case borrowed
}
#endif
