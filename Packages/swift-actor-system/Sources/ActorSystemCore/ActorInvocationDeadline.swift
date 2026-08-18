import Synchronization

final class ActorInvocationDeadline<Value: Sendable>: Sendable {
    private enum Outcome: Sendable {
        case success(Value)
        case failure(any Error)
    }

    private struct State: Sendable {
        var continuation: CheckedContinuation<Value, Error>?
        var outcome: Outcome?
        var operationTask: Task<Void, Never>?
        var timeoutTask: Task<Void, Never>?
    }

    private let state = Mutex(State())

    func run(
        taskRegistry: ActorInvocationTaskRegistry,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let outcome = register(continuation) {
                    resume(continuation, with: outcome)
                    return
                }
                do {
                    let operationTask = try taskRegistry.schedule {
                        do {
                            self.resolve(.success(try await operation()))
                        } catch is CancellationError {
                            self.resolve(.failure(ActorSystemError.cancelled))
                        } catch {
                            self.resolve(.failure(error))
                        }
                    }
                    install(operationTask: operationTask, timeoutTask: nil)
                } catch {
                    resolve(.failure(error))
                }
            }
        } onCancel: {
            self.resolve(.failure(ActorSystemError.cancelled))
        }
    }

    func run(
        timeout: Duration,
        clock: any ActorClock,
        taskRegistry: ActorInvocationTaskRegistry,
        operation: @escaping @Sendable () async throws -> Value
    ) async throws -> Value {
        guard timeout > .zero else {
            throw ActorSystemError.timeout
        }

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                if let outcome = register(continuation) {
                    resume(continuation, with: outcome)
                    return
                }

                do {
                    let tasks = try taskRegistry.schedule([
                        {
                            do {
                                self.resolve(.success(try await operation()))
                            } catch is CancellationError {
                                self.resolve(.failure(ActorSystemError.cancelled))
                            } catch {
                                self.resolve(.failure(error))
                            }
                        },
                        {
                            do {
                                try await clock.sleep(for: timeout)
                                self.resolve(.failure(ActorSystemError.timeout))
                            } catch is CancellationError {
                                return
                            } catch {
                                self.resolve(.failure(error))
                            }
                        },
                    ])
                    install(operationTask: tasks[0], timeoutTask: tasks[1])
                } catch {
                    resolve(.failure(error))
                }
            }
        } onCancel: {
            self.resolve(.failure(ActorSystemError.cancelled))
        }
    }

    private func register(
        _ continuation: CheckedContinuation<Value, Error>
    ) -> Outcome? {
        state.withLock { state in
            if let outcome = state.outcome {
                return outcome
            }
            state.continuation = continuation
            return nil
        }
    }

    private func install(
        operationTask: Task<Void, Never>,
        timeoutTask: Task<Void, Never>?
    ) {
        let alreadyResolved = state.withLock { state in
            guard state.outcome == nil else {
                return true
            }
            state.operationTask = operationTask
            state.timeoutTask = timeoutTask
            return false
        }
        if alreadyResolved {
            operationTask.cancel()
            timeoutTask?.cancel()
        }
    }

    private func resolve(_ outcome: consuming Outcome) {
        let completion = state.withLock { state -> (
            CheckedContinuation<Value, Error>?,
            Task<Void, Never>?,
            Task<Void, Never>?
        )? in
            guard state.outcome == nil else {
                return nil
            }
            state.outcome = copy outcome
            let completion = (
                state.continuation,
                state.operationTask,
                state.timeoutTask
            )
            state.continuation = nil
            state.operationTask = nil
            state.timeoutTask = nil
            return completion
        }
        guard let completion else {
            return
        }
        completion.1?.cancel()
        completion.2?.cancel()
        if let continuation = completion.0 {
            let storedOutcome = state.withLock { state -> Outcome in
                guard let outcome = state.outcome else {
                    preconditionFailure("Resolved deadline lost its outcome")
                }
                return outcome
            }
            resume(continuation, with: storedOutcome)
        }
    }

    private func resume(
        _ continuation: CheckedContinuation<Value, Error>,
        with outcome: Outcome
    ) {
        switch outcome {
        case .success(let value):
            continuation.resume(returning: value)
        case .failure(let error):
            continuation.resume(throwing: error)
        }
    }
}
