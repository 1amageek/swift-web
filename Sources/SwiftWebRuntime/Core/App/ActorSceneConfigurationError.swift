#if SWIFTWEB_ACTORS
/// Configuration errors detected while lowering actor scenes. These are
/// programmer errors surfaced at scene build rather than silently ignored.
public enum ActorSceneConfigurationError: Error, Sendable, Equatable {
    /// A `.transient` scope was combined with a passivation policy: a
    /// transient actor dies with its connection, so passivation is
    /// meaningless for it.
    case transientScopeCannotPassivate(contract: String)
}
#endif
