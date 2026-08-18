#if SWIFTWEB_ACTORS
public enum SwiftWebActorSystemConfigurationError: Error, Sendable, Equatable {
    case conflictingActorHosts
    case conflictingLocalInvocationOwners
}
#endif
