import Synchronization

/// Owns invocation-support tasks until they actually finish.
///
/// Cancellation is cooperative in Swift. A deadline may therefore resume its
/// caller before the cancelled operation exits. Keeping the task registered
/// lets Core cancel it again during shutdown and prevents shutdown from
/// completing while actor code is still running.
final class ActorInvocationTaskRegistry: Sendable {
    private struct State: Sendable {
        var accepting = true
        var nextID: UInt64 = 0
        var tasks: [UInt64: Task<Void, Never>] = [:]
    }

    private let maximumCount: Int
    private let owner: ActorOwnedTaskOwner
    private let taskKind: ActorOwnedTaskKind
    private let state = Mutex(State())

    init(
        maximumCount: Int,
        owner: ActorOwnedTaskOwner = ActorOwnedTaskOwner(),
        taskKind: ActorOwnedTaskKind = .invocation
    ) {
        self.maximumCount = maximumCount
        self.owner = owner
        self.taskKind = taskKind
    }

    func schedule(
        _ operation: @escaping @Sendable () async -> Void
    ) throws -> Task<Void, Never> {
        guard let task = try schedule([operation]).first else {
            preconditionFailure("Invocation task registration produced no task")
        }
        return task
    }

    /// Registers every task in the batch before any operation can run.
    ///
    /// Deadline execution uses this to avoid starting actor work when its
    /// companion timeout task cannot be retained within the ownership bound.
    func schedule(
        _ operations: [@Sendable () async -> Void]
    ) throws -> [Task<Void, Never>] {
        guard !operations.isEmpty else {
            return []
        }
        var gate: ActorTaskStartGate?
        let tasks = try state.withLock { state -> [Task<Void, Never>] in
            guard state.accepting else {
                throw ActorSystemError.shuttingDown
            }
            guard maximumCount >= operations.count,
                  state.tasks.count <= maximumCount - operations.count
            else {
                throw ActorSystemError.overloaded
            }
            let requiredIDs = UInt64(operations.count)
            if state.nextID > UInt64.max - requiredIDs {
                guard state.tasks.isEmpty else {
                    throw ActorSystemError.overloaded
                }
                state.nextID = 0
            }
            let taskGate = ActorTaskStartGate()
            var tasks: [Task<Void, Never>] = []
            tasks.reserveCapacity(operations.count)
            for operation in operations {
                state.nextID += 1
                let id = state.nextID
                let identity = ActorOwnedTaskIdentity(
                    owner: owner,
                    kind: taskKind
                )
                let task = Task {
                    await ActorOwnedTaskContext.$current.withValue(identity) {
                        await taskGate.wait()
                        await operation()
                        self.finished(id: id)
                    }
                }
                state.tasks[id] = task
                tasks.append(task)
            }
            gate = taskGate
            return tasks
        }
        gate?.start()
        return tasks
    }

    func stopAcceptingAndCancel() -> [Task<Void, Never>] {
        let tasks = state.withLock { state -> [Task<Void, Never>] in
            state.accepting = false
            let tasks = Array(state.tasks.values)
            state.tasks.removeAll(keepingCapacity: false)
            return tasks
        }
        for task in tasks {
            task.cancel()
        }
        return tasks
    }

    private func finished(id: UInt64) {
        state.withLock { state in
            state.tasks[id] = nil
        }
    }
}
