#if SWIFTWEB_ACTORS
import Distributed

/// Optional lifecycle hooks for virtual actors hosted by `WebActorSystem`.
///
/// `activated()` runs after the actor is constructed for an addressed
/// identity and its `@ActorStorage` grain state is restored — cold start
/// and resume are the same path. `passivating()` runs right before an idle
/// instance is evicted; grain state mutated by the hook is persisted after
/// it returns. Both hooks default to no-ops, so actors adopt only what
/// they need.
public protocol WebActorLifecycle: DistributedActor {
    /// Called after activation, once grain state has been restored.
    func activated() async

    /// Called before passivation; the last work before hibernation.
    func passivating() async
}

public extension WebActorLifecycle {
    func activated() async {}
    func passivating() async {}
}
#endif
