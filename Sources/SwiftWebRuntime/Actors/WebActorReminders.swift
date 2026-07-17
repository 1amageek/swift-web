#if SWIFTWEB_ACTORS
import Distributed
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

/// The actor-facing handle for scheduling durable reminders:
///
///     distributed actor DigestAgent: WebActorRemindable {
///         distributed func schedule() async throws {
///             try await reminders.set("daily-digest", in: .hours(24))
///         }
///
///         func reminder(_ name: String) async throws { ... }
///     }
///
/// Scheduling requires an installed `WebActorReminderStore`; without one,
/// `set` throws — durability is a host configuration, not a silent no-op.
public struct WebActorReminders: Sendable {
    private let actorID: WebActorSystem.ActorID
    private let store: (any WebActorReminderStore)?

    init(actorID: WebActorSystem.ActorID, store: (any WebActorReminderStore)?) {
        self.actorID = actorID
        self.store = store
    }

    /// Schedules the named reminder to fire after the given delay.
    public func set(_ name: String, in delay: Duration) async throws {
        try await set(name, at: Date().addingTimeInterval(delay.timeInterval))
    }

    /// Schedules the named reminder to fire at the given date.
    public func set(_ name: String, at fireDate: Date) async throws {
        guard let store else {
            throw WebActorReminderError.storeNotInstalled(actorID: actorID)
        }
        try await store.set(WebActorReminder(actorID: actorID, name: name, fireDate: fireDate))
    }

    /// Cancels the named reminder, if scheduled.
    public func cancel(_ name: String) async throws {
        guard let store else {
            throw WebActorReminderError.storeNotInstalled(actorID: actorID)
        }
        try await store.cancel(actorID: actorID, name: name)
    }

    /// The actor's pending reminders.
    public func pending() async throws -> [WebActorReminder] {
        guard let store else {
            throw WebActorReminderError.storeNotInstalled(actorID: actorID)
        }
        return try await store.pending(actorID: actorID)
    }
}

/// Errors raised by the reminder machinery.
public enum WebActorReminderError: Error, Sendable, Equatable {
    /// No `WebActorReminderStore` is installed on the actor system.
    case storeNotInstalled(actorID: WebActorSystem.ActorID)
    /// A reminder fired for an actor that does not adopt `WebActorRemindable`.
    case actorNotRemindable(actorID: WebActorSystem.ActorID, name: String)
}

public extension DistributedActor where ActorSystem == WebActorSystem, ID == WebActorSystem.ActorID {
    /// The durable reminder handle for this actor's identity.
    var reminders: WebActorReminders {
        actorSystem.reminders(for: id)
    }
}
#endif
