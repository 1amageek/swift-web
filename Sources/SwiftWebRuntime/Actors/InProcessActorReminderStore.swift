#if SWIFTWEB_ACTORS
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif
import Synchronization

/// A process-lifetime reminder store for native hosts and tests: reminders
/// survive actor passivation but not process restarts. Durability across
/// restarts requires a host-backed store (the Cloudflare host lowers onto
/// Durable Object Alarms).
public final class InProcessActorReminderStore: WebActorReminderStore, Sendable {
    private struct Key: Hashable, Sendable {
        let actorID: WebActorSystem.ActorID
        let name: String
    }

    private struct Entry: Sendable {
        let reminder: WebActorReminder
        let task: Task<Void, Never>
    }

    private let entries = Mutex<[Key: Entry]>([:])
    private let deliver: @Sendable (WebActorReminder) async -> Void

    /// - Parameter deliver: Invoked when a reminder fires. Wire this to
    ///   `WebActorSystem.deliverReminder(_:)`; delivery failures are the
    ///   delegate's to surface (log, retry, or dead-letter) — the store's
    ///   contract is only the timing.
    public init(deliver: @escaping @Sendable (WebActorReminder) async -> Void) {
        self.deliver = deliver
    }

    public func set(_ reminder: WebActorReminder) async throws {
        let key = Key(actorID: reminder.actorID, name: reminder.name)
        let delay = max(0, reminder.fireDate.timeIntervalSinceNow)
        let deliver = self.deliver
        let task = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                return  // Cancelled: the reminder was rescheduled or removed.
            }
            self?.remove(key)
            await deliver(reminder)
        }
        let replaced = entries.withLock { entries -> Entry? in
            let previous = entries[key]
            entries[key] = Entry(reminder: reminder, task: task)
            return previous
        }
        replaced?.task.cancel()
    }

    public func cancel(actorID: WebActorSystem.ActorID, name: String) async throws {
        let key = Key(actorID: actorID, name: name)
        let removed = entries.withLock { $0.removeValue(forKey: key) }
        removed?.task.cancel()
    }

    public func pending(actorID: WebActorSystem.ActorID) async throws -> [WebActorReminder] {
        entries.withLock { entries in
            entries.values
                .map(\.reminder)
                .filter { $0.actorID == actorID }
                .sorted { $0.fireDate < $1.fireDate }
        }
    }

    private func remove(_ key: Key) {
        _ = entries.withLock { $0.removeValue(forKey: key) }
    }
}
#endif
