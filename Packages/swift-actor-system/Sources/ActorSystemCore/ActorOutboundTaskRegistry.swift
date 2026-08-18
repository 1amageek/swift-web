import Synchronization

final class ActorOutboundTaskRegistry: Sendable {
    enum ScheduleResult: Sendable, Equatable {
        case scheduled
        case shuttingDown
        case overloaded
        case duplicate
    }

    enum Kind: UInt8, Hashable, Sendable {
        case invocation
        case timeoutCancellation
        case callerCancellation
    }

    struct Key: Hashable, Sendable {
        let callID: ActorCallID
        let kind: Kind
    }

    private struct Entry: Sendable {
        let transport: ActorTransportID
        let endpoint: ActorEndpoint
        let task: Task<Void, Never>
    }

    private struct State: Sendable {
        var accepting = true
        var entries: [Key: Entry] = [:]
    }

    private let maximumCount: Int
    private let owner: ActorOwnedTaskOwner
    private let state = Mutex(State())

    init(
        maximumCount: Int,
        owner: ActorOwnedTaskOwner = ActorOwnedTaskOwner()
    ) {
        self.maximumCount = maximumCount
        self.owner = owner
    }

    /// Creates and registers the task before its operation is allowed to run.
    /// The start gate prevents shutdown from missing a newly created task.
    @discardableResult
    func schedule(
        key: Key,
        transport: ActorTransportID,
        endpoint: ActorEndpoint,
        operation: @escaping @Sendable () async -> Void
    ) -> ScheduleResult {
        var gate: ActorTaskStartGate?
        let result = state.withLock { state -> ScheduleResult in
            guard state.accepting else {
                return .shuttingDown
            }
            guard state.entries.count < maximumCount else {
                return .overloaded
            }
            guard state.entries[key] == nil else {
                return .duplicate
            }
            let taskGate = ActorTaskStartGate()
            let identity = ActorOwnedTaskIdentity(owner: owner, kind: .outbound)
            let task = Task {
                await ActorOwnedTaskContext.$current.withValue(identity) {
                    await taskGate.wait()
                    await operation()
                    self.finished(key: key)
                }
            }
            state.entries[key] = Entry(
                transport: transport,
                endpoint: endpoint,
                task: task
            )
            gate = taskGate
            return .scheduled
        }
        gate?.start()
        return result
    }

    func endpointClosed(
        transport: ActorTransportID,
        endpoint: ActorEndpoint
    ) async {
        let tasks = state.withLock { state -> [(Key, Task<Void, Never>)] in
            state.entries.compactMap { key, entry in
                entry.transport == transport && entry.endpoint == endpoint
                    ? (key, entry.task)
                    : nil
            }
        }
        await cancelAndJoin(tasks)
    }

    func transportClosed(_ transport: ActorTransportID) async {
        let tasks = state.withLock { state -> [(Key, Task<Void, Never>)] in
            state.entries.compactMap { key, entry in
                entry.transport == transport ? (key, entry.task) : nil
            }
        }
        await cancelAndJoin(tasks)
    }

    func stopAcceptingAndCancel() -> [Task<Void, Never>] {
        let tasks = state.withLock { state -> [Task<Void, Never>] in
            state.accepting = false
            let tasks = state.entries.values.map { $0.task }
            state.entries.removeAll(keepingCapacity: false)
            return tasks
        }
        for task in tasks {
            task.cancel()
        }
        return tasks
    }

    private func finished(key: Key) {
        state.withLock { state in
            state.entries[key] = nil
        }
    }

    private func cancelAndJoin(_ tasks: [Task<Void, Never>]) async {
        for task in tasks {
            task.cancel()
        }
        for task in tasks {
            await task.value
        }
    }

    private func cancelAndJoin(
        _ entries: [(Key, Task<Void, Never>)]
    ) async {
        await cancelAndJoin(entries.map { $0.1 })
        state.withLock { state in
            for (key, _) in entries {
                state.entries[key] = nil
            }
        }
    }
}
