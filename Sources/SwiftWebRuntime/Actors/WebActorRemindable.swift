#if SWIFTWEB_ACTORS
import ActorSystemCore
import Distributed

/// Receives durable reminder deliveries. An actor that schedules reminders
/// through `reminders` must conform; delivery to a non-conforming actor is
/// an explicit error, not a silent drop.
public protocol WebActorRemindable: DistributedActor {
    /// Called when the named reminder fires. The actor is re-activated
    /// first if it was passivated, with grain state restored.
    func reminder(_ name: String) async throws
}

public extension DistributedActor
where ActorSystem == WebActorSystem, ID == ActorAddress {
    var reminders: SwiftWebActorReminders {
        actorSystem.reminders(for: id)
    }
}
#endif
