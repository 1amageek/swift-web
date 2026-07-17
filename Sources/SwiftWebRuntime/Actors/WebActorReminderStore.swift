#if SWIFTWEB_ACTORS
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// A scheduled wake-up for a virtual actor. Reminders are durable in the
/// Orleans sense: they fire while the actor is passivated and re-activate
/// it, unlike in-memory timers that die with the instance.
public struct WebActorReminder: Sendable, Equatable, Codable {
    /// The actor identity the reminder re-activates.
    public let actorID: WebActorSystem.ActorID
    /// The reminder name delivered to `WebActorRemindable.reminder(_:)`.
    public let name: String
    /// When the reminder fires.
    public let fireDate: Date

    public init(actorID: WebActorSystem.ActorID, name: String, fireDate: Date) {
        self.actorID = actorID
        self.name = name
        self.fireDate = fireDate
    }
}

/// The durable backend that persists and fires actor reminders. Hosts
/// install one with `WebActorSystem.setReminderStore(_:)`: the Cloudflare
/// host lowers reminders onto Durable Object Alarms; native hosts can use
/// `InProcessActorReminderStore` for process-lifetime scheduling.
public protocol WebActorReminderStore: Sendable {
    /// Schedules (or reschedules) the reminder; one reminder per
    /// (actorID, name) pair.
    func set(_ reminder: WebActorReminder) async throws

    /// Cancels the named reminder for the actor, if scheduled.
    func cancel(actorID: WebActorSystem.ActorID, name: String) async throws

    /// The pending reminders for the actor.
    func pending(actorID: WebActorSystem.ActorID) async throws -> [WebActorReminder]
}
#endif
