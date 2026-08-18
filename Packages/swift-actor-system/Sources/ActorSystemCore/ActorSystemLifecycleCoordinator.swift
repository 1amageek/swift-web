/// Serializes start and terminal cleanup for actor-system facades.
///
/// Shutdown is intentionally split into request and wait operations. This keeps
/// the completion contract identical for Native, WASM, and Embedded profiles
/// without exposing Core task registries or task-local ownership markers.
@_spi(ActorSystemLifecycleOwnership)
public actor ActorSystemLifecycleCoordinator {
    private enum Phase: Sendable, Equatable {
        case initialized
        case starting
        case running
        case shuttingDown
        case stopped
    }

    private let startValue: @Sendable () async throws -> Void
    private let requestShutdownValue: @Sendable () async -> ActorSystemTermination
    private let ownedTaskOwner = ActorOwnedTaskOwner()
    private var phase = Phase.initialized
    private var startTask: Task<Void, any Error>?
    private var termination: ActorSystemTermination?

    public init(
        start: @escaping @Sendable () async throws -> Void,
        requestShutdown: @escaping @Sendable () async -> ActorSystemTermination
    ) {
        self.startValue = start
        self.requestShutdownValue = requestShutdown
    }

    public func start() async throws {
        switch phase {
        case .running:
            return
        case .starting:
            guard ActorOwnedTaskContext.current?.contains(owner: ownedTaskOwner) != true else {
                throw ActorSystemError.alreadyStarted
            }
            guard let startTask else {
                throw ActorSystemError.notStarted
            }
            try await withTaskCancellationHandler {
                try await startTask.value
            } onCancel: {
                startTask.cancel()
            }
            return
        case .shuttingDown, .stopped:
            throw ActorSystemError.shuttingDown
        case .initialized:
            break
        }

        phase = .starting
        let identity = ActorOwnedTaskIdentity(owner: ownedTaskOwner, kind: .start)
        let task = Task {
            try await ActorOwnedTaskContext.$current.withValue(identity) {
                try await startValue()
            }
        }
        startTask = task
        do {
            try await withTaskCancellationHandler {
                try await task.value
            } onCancel: {
                task.cancel()
            }
            startTask = nil
            guard phase == .starting else {
                throw ActorSystemError.shuttingDown
            }
            phase = .running
        } catch {
            startTask = nil
            if phase == .starting {
                phase = .initialized
            }
            let termination = requestShutdown()
            try await termination.wait()
            throw error
        }
    }

    public func requestShutdown() -> ActorSystemTermination {
        if let termination {
            return termination
        }
        guard phase != .stopped else {
            return .alreadyTerminated()
        }

        let pendingStart = startTask
        let ownedTaskOwner = ownedTaskOwner
        phase = .shuttingDown
        pendingStart?.cancel()
        let termination = ActorSystemTermination(
            waitIsReentrant: {
                ActorOwnedTaskContext.current?.contains(owner: ownedTaskOwner) == true
            },
            dependencies: { [requestShutdownValue] in
                [await requestShutdownValue()]
            },
            operation: {
                if let pendingStart {
                    do {
                        try await pendingStart.value
                    } catch {
                        // Terminal cleanup owns a partially completed start.
                    }
                }
                await self.completeShutdown()
            }
        )
        self.termination = termination
        return termination
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }

    private func completeShutdown() {
        startTask = nil
        phase = .stopped
    }
}
