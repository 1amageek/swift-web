#if SWIFTWEB_LEGACY_ACTORS
@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
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
        let actorID: LegacyWebActorSystem.ActorID
        let name: String
    }

    private struct Entry: Sendable {
        let id: UInt64
        let reminder: WebActorReminder
        let task: Task<Void, Never>
    }

    private struct State: Sendable {
        var accepting = true
        var nextID: UInt64 = 0
        var entries: [Key: Entry] = [:]
        var tasks: [UInt64: Task<Void, Never>] = [:]
        var termination: ActorSystemTermination?
    }

    private final class TaskOwner: Sendable {}

    private enum TaskContext {
        @TaskLocal static var owner: TaskOwner?
    }

    private actor StartGate {
        private var started = false
        private var waiters: [CheckedContinuation<Void, Never>] = []

        func wait() async {
            guard !started else {
                return
            }
            await withCheckedContinuation { continuation in
                waiters.append(continuation)
            }
        }

        func start() {
            started = true
            let waiters = waiters
            self.waiters.removeAll(keepingCapacity: false)
            for waiter in waiters {
                waiter.resume()
            }
        }
    }

    private let state = Mutex(State())
    private let taskOwner = TaskOwner()
    private let maximumPendingTasks: Int
    private let deliver: @Sendable (WebActorReminder) async -> Void

    /// - Parameter deliver: Invoked when a reminder fires. Wire this to
    ///   `LegacyWebActorSystem.deliverReminder(_:)`; delivery failures are the
    ///   delegate's to surface (log, retry, or dead-letter) — the store's
    ///   contract is only the timing.
    public init(
        maximumPendingTasks: Int = 1_024,
        deliver: @escaping @Sendable (WebActorReminder) async -> Void
    ) throws {
        guard maximumPendingTasks > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Legacy reminder task limit is invalid")
            )
        }
        self.maximumPendingTasks = maximumPendingTasks
        self.deliver = deliver
    }

    public func set(_ reminder: WebActorReminder) async throws {
        let key = Key(actorID: reminder.actorID, name: reminder.name)
        let delay = max(0, reminder.fireDate.timeIntervalSinceNow)
        let deliver = self.deliver
        let gate = StartGate()
        let replaced = try state.withLock { state -> Entry? in
            guard state.accepting else {
                throw ActorSystemError.shuttingDown
            }
            guard state.tasks.count < maximumPendingTasks else {
                throw ActorSystemError.overloaded
            }
            if state.nextID == UInt64.max {
                guard state.tasks.isEmpty else {
                    throw ActorSystemError.overloaded
                }
                state.nextID = 0
            }
            state.nextID += 1
            let id = state.nextID
            let taskOwner = taskOwner
            let task = Task { [weak self] in
                await TaskContext.$owner.withValue(taskOwner) {
                    await gate.wait()
                    defer { self?.finished(key, id: id) }
                    do {
                        try await Task.sleep(for: .seconds(delay))
                    } catch {
                        return
                    }
                    guard self?.isCurrent(key, id: id) == true else {
                        return
                    }
                    await deliver(reminder)
                }
            }
            let previous = state.entries[key]
            state.entries[key] = Entry(id: id, reminder: reminder, task: task)
            state.tasks[id] = task
            return previous
        }
        replaced?.task.cancel()
        await gate.start()
    }

    public func cancel(actorID: LegacyWebActorSystem.ActorID, name: String) async throws {
        let key = Key(actorID: actorID, name: name)
        let removed = try state.withLock { state -> Entry? in
            guard state.accepting else {
                throw ActorSystemError.shuttingDown
            }
            return state.entries.removeValue(forKey: key)
        }
        removed?.task.cancel()
    }

    public func pending(actorID: LegacyWebActorSystem.ActorID) async throws -> [WebActorReminder] {
        try state.withLock { state in
            guard state.accepting else {
                throw ActorSystemError.shuttingDown
            }
            return state.entries.values
                .map(\.reminder)
                .filter { $0.actorID == actorID }
                .sorted { $0.fireDate < $1.fireDate }
        }
    }

    public func requestShutdown() -> ActorSystemTermination {
        state.withLock { state in
            if let termination = state.termination {
                return termination
            }
            state.accepting = false
            let tasks = Array(state.tasks.values)
            state.entries.removeAll(keepingCapacity: false)
            state.tasks.removeAll(keepingCapacity: false)
            let taskOwner = taskOwner
            let termination = ActorSystemTermination(
                waitIsReentrant: {
                    TaskContext.owner === taskOwner
                },
                operation: {
                    for task in tasks {
                        task.cancel()
                    }
                    for task in tasks {
                        await task.value
                    }
                }
            )
            state.termination = termination
            return termination
        }
    }

    private func finished(_ key: Key, id: UInt64) {
        state.withLock { state in
            if state.entries[key]?.id == id {
                state.entries[key] = nil
            }
            state.tasks[id] = nil
        }
    }

    private func isCurrent(_ key: Key, id: UInt64) -> Bool {
        state.withLock { $0.entries[key]?.id == id }
    }
}
#endif
