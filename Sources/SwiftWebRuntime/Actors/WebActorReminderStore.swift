#if SWIFTWEB_LEGACY_ACTORS
import ActorSystemCore
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
    public let actorID: LegacyWebActorSystem.ActorID
    /// The reminder name delivered to `WebActorRemindable.reminder(_:)`.
    public let name: String
    /// When the reminder fires.
    public let fireDate: Date

    public init(actorID: LegacyWebActorSystem.ActorID, name: String, fireDate: Date) {
        self.actorID = actorID
        self.name = name
        self.fireDate = fireDate
    }
}

/// The durable backend that persists and fires actor reminders. Hosts
/// install one with `LegacyWebActorSystem.setReminderStore(_:)`: the Cloudflare
/// host lowers reminders onto Durable Object Alarms; native hosts can use
/// `InProcessActorReminderStore` for process-lifetime scheduling.
public protocol WebActorReminderStore: Sendable {
    /// Schedules (or reschedules) the reminder; one reminder per
    /// (actorID, name) pair.
    func set(_ reminder: WebActorReminder) async throws

    /// Cancels the named reminder for the actor, if scheduled.
    func cancel(actorID: LegacyWebActorSystem.ActorID, name: String) async throws

    /// The pending reminders for the actor.
    func pending(actorID: LegacyWebActorSystem.ActorID) async throws -> [WebActorReminder]

    /// Stops admission and returns the completion for all store-owned tasks.
    func requestShutdown() -> ActorSystemTermination
}

public extension WebActorReminderStore {
    func shutdown() async throws {
        try await requestShutdown().wait()
    }
}
#endif
