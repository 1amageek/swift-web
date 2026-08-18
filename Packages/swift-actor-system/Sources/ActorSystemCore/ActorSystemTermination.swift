import Synchronization

/// An opaque, shareable handle for one terminal actor-system cleanup.
///
/// `requestShutdown()` returns this handle without joining work that may include
/// the caller. `wait()` rejects such a self-join and lets an external lifetime
/// owner await the same cleanup to completion.
public final class ActorSystemTermination: Sendable {
    typealias WaitValidation = @Sendable () -> Bool

    private struct State: Sendable {
        var isTerminated: Bool
        var failure: (any Error)?
    }

    private final class StateStorage: Sendable {
        let value: Mutex<State>

        init(_ state: State) {
            self.value = Mutex(state)
        }
    }

    private let state: StateStorage
    private let dependenciesTask: Task<[ActorSystemTermination], Never>
    private let task: Task<Void, Never>
    private let waitIsReentrant: WaitValidation

    private init(alreadyTerminated: Void) {
        self.state = StateStorage(State(isTerminated: true, failure: nil))
        self.dependenciesTask = Task.detached { [] }
        self.task = Task.detached {}
        self.waitIsReentrant = { false }
    }

    private init(
        waitValidation: @escaping WaitValidation,
        dependencies: @escaping @Sendable () async -> [ActorSystemTermination] = { [] },
        operation: @escaping @Sendable () async throws -> Void = {}
    ) {
        let state = StateStorage(State(isTerminated: false, failure: nil))
        let dependenciesTask = Task.detached {
            await dependencies()
        }
        self.state = state
        self.dependenciesTask = dependenciesTask
        self.waitIsReentrant = waitValidation
        self.task = Task.detached {
            let dependencies = await dependenciesTask.value
            var firstFailure: (any Error)?
            for dependency in dependencies {
                await dependency.task.value
                if firstFailure == nil {
                    firstFailure = dependency.state.value.withLock { $0.failure }
                }
            }
            do {
                try await operation()
            } catch {
                if firstFailure == nil {
                    firstFailure = error
                }
            }
            state.value.withLock { state in
                state.failure = firstFailure
                state.isTerminated = true
            }
        }
    }

    @_spi(ActorSystemLifecycleOwnership)
    public convenience init(
        dependencies: @escaping @Sendable () async -> [ActorSystemTermination] = { [] },
        operation: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.init(
            waitValidation: { false },
            dependencies: dependencies,
            operation: operation
        )
    }

    @_spi(ActorSystemLifecycleOwnership)
    public convenience init(
        waitIsReentrant: @escaping @Sendable () -> Bool,
        dependencies: @escaping @Sendable () async -> [ActorSystemTermination] = { [] },
        operation: @escaping @Sendable () async throws -> Void = {}
    ) {
        self.init(
            waitValidation: waitIsReentrant,
            dependencies: dependencies,
            operation: operation
        )
    }

    public var isTerminated: Bool {
        state.value.withLock { $0.isTerminated }
    }

    public func wait() async throws {
        try await validateWait()
        await task.value
        if let failure = state.value.withLock({ $0.failure }) {
            throw failure
        }
    }

    /// Joins a dependency from a detached lifecycle-owner cleanup task.
    /// Public callers must use `wait()` so self-join validation remains active.
    @_spi(ActorSystemLifecycleOwnership)
    public func waitForCompletionAsDependency() async throws {
        await task.value
        if let failure = state.value.withLock({ $0.failure }) {
            throw failure
        }
    }

    @_spi(ActorSystemLifecycleOwnership)
    public var terminationError: (any Error)? {
        state.value.withLock { state in
            guard state.isTerminated else {
                return nil
            }
            return state.failure
        }
    }

    @_spi(ActorSystemLifecycleOwnership)
    public static func alreadyTerminated() -> ActorSystemTermination {
        ActorSystemTermination(alreadyTerminated: ())
    }

    private func validateWait() async throws {
        guard !waitIsReentrant() else {
            throw ActorSystemTerminationError.reentrantWait
        }
        let dependencies = await dependenciesTask.value
        for dependency in dependencies {
            try await dependency.validateWait()
        }
    }
}
