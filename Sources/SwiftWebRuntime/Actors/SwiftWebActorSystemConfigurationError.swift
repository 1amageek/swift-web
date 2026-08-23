#if SWIFTWEB_ACTORS || hasFeature(Embedded)
public enum SwiftWebActorSystemConfigurationError: Error, Sendable, Equatable {
    case conflictingActorHosts
    case conflictingLocalInvocationOwners
    case routeBindingsUnsupported
}
#endif
