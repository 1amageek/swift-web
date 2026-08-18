import Synchronization

/// Owns one incoming-frame consumer for each started transport.
///
/// The start gate makes registration visible before transport input can call
/// back into Core. Terminal cleanup closes admission and takes ownership of
/// every registered task before cancelling it.
final class ActorConsumerTaskRegistry: Sendable {
    private struct State: Sendable {
        var accepting = true
        var tasks: [ActorTransportID: Task<Void, Never>] = [:]
    }

    private let owner: ActorOwnedTaskOwner
    private let state = Mutex(State())

    init(owner: ActorOwnedTaskOwner) {
        self.owner = owner
    }

    func schedule(
        transport: ActorTransportID,
        operation: @escaping @Sendable () async -> Void
    ) throws {
        var gate: ActorTaskStartGate?
        try state.withLock { state in
            guard state.accepting else {
                throw ActorSystemError.shuttingDown
            }
            guard state.tasks[transport] == nil else {
                throw ActorSystemError.alreadyStarted
            }
            let taskGate = ActorTaskStartGate()
            let identity = ActorOwnedTaskIdentity(owner: owner, kind: .consumer)
            let task = Task {
                await ActorOwnedTaskContext.$current.withValue(identity) {
                    await taskGate.wait()
                    await operation()
                    self.finished(transport: transport)
                }
            }
            state.tasks[transport] = task
            gate = taskGate
        }
        gate?.start()
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

    private func finished(transport: ActorTransportID) {
        state.withLock { state in
            state.tasks[transport] = nil
        }
    }
}
