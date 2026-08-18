#if SWIFTWEB_ACTORS
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#elseif canImport(Foundation)
import Foundation
#endif

public actor InProcessSwiftWebActorReminderStore: SwiftWebActorReminderStore {
    private enum Phase: Sendable, Equatable {
        case running
        case shuttingDown
        case stopped
    }

    private struct Key: Hashable, Sendable {
        let actorAddress: ActorAddress
        let name: String
    }

    private struct Entry: Sendable {
        let reminder: SwiftWebActorReminder
        let generation: UInt64
    }

    private let deliver: @Sendable (SwiftWebActorReminder) async -> Void
    private let maximumPendingTasks: Int
    private var entries: [Key: Entry] = [:]
    private var tasks: [UInt64: Task<Void, Never>] = [:]
    private var nextGeneration: UInt64 = 0
    private var phase = Phase.running
    private var shutdownWaiters: [CheckedContinuation<Void, Never>] = []

    public init(
        maximumPendingTasks: Int = 1_024,
        deliver: @escaping @Sendable (SwiftWebActorReminder) async -> Void
    ) throws {
        guard maximumPendingTasks > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Reminder task limit is invalid")
            )
        }
        self.maximumPendingTasks = maximumPendingTasks
        self.deliver = deliver
    }

    public func set(_ reminder: SwiftWebActorReminder) async throws {
        guard phase == .running else {
            throw ActorSystemError.shuttingDown
        }
        guard tasks.count < maximumPendingTasks else {
            throw ActorSystemError.overloaded
        }
        if nextGeneration == UInt64.max {
            guard tasks.isEmpty else {
                throw ActorSystemError.overloaded
            }
            nextGeneration = 0
        }
        nextGeneration += 1
        let generation = nextGeneration
        let key = Key(
            actorAddress: reminder.actorAddress,
            name: reminder.name
        )
        let replacedGeneration = entries[key]?.generation
        let delay = max(0, reminder.fireDate.timeIntervalSinceNow)
        let task = Task { [weak self] in
            do {
                try await Task.sleep(for: .seconds(delay))
            } catch {
                await self?.taskFinished(generation: generation)
                return
            }
            guard !Task.isCancelled else {
                await self?.taskFinished(generation: generation)
                return
            }
            await self?.fire(
                key: key,
                generation: generation,
                reminder: reminder
            )
            await self?.taskFinished(generation: generation)
        }
        tasks[generation] = task
        entries[key] = Entry(
            reminder: reminder,
            generation: generation
        )
        if let replacedGeneration {
            tasks[replacedGeneration]?.cancel()
        }
    }

    public func cancel(
        actorAddress: ActorAddress,
        name: String
    ) async throws {
        guard phase == .running else {
            throw ActorSystemError.shuttingDown
        }
        let key = Key(actorAddress: actorAddress, name: name)
        guard let entry = entries.removeValue(forKey: key),
              let task = tasks[entry.generation]
        else {
            return
        }
        task.cancel()
        await task.value
    }

    public func pending(
        actorAddress: ActorAddress
    ) async throws -> [SwiftWebActorReminder] {
        guard phase == .running else {
            throw ActorSystemError.shuttingDown
        }
        return entries.values
            .map(\.reminder)
            .filter { $0.actorAddress == actorAddress }
            .sorted { $0.fireDate < $1.fireDate }
    }

    public func shutdown() async {
        switch phase {
        case .stopped:
            return
        case .shuttingDown:
            await withCheckedContinuation { continuation in
                shutdownWaiters.append(continuation)
            }
            return
        case .running:
            phase = .shuttingDown
        }
        entries.removeAll(keepingCapacity: false)
        let pendingTasks = Array(tasks.values)
        for task in pendingTasks {
            task.cancel()
        }
        for task in pendingTasks {
            await task.value
        }
        tasks.removeAll(keepingCapacity: false)
        phase = .stopped
        let waiters = shutdownWaiters
        shutdownWaiters.removeAll(keepingCapacity: false)
        for waiter in waiters {
            waiter.resume()
        }
    }

    private func fire(
        key: Key,
        generation: UInt64,
        reminder: SwiftWebActorReminder
    ) async {
        guard phase == .running,
              entries[key]?.generation == generation,
              entries[key]?.reminder == reminder
        else {
            return
        }
        await deliver(reminder)
        if entries[key]?.generation == generation {
            entries[key] = nil
        }
    }

    private func taskFinished(generation: UInt64) {
        tasks[generation] = nil
    }
}
#endif
