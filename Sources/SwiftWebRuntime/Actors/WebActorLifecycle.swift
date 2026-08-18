#if SWIFTWEB_ACTORS
import Distributed

/// Optional lifecycle hooks for virtual actors hosted by `SwiftWebActorHost`.
///
/// `activated()` runs after the actor is constructed for an addressed identity
/// and its `@ActorStorage` grain state is restored. `passivating()` runs right
/// before an idle instance is evicted. Both hooks default to no-ops.
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
