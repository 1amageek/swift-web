import Synchronization

final class SwiftWebActorTaskStartGate: Sendable {
    private struct State: Sendable {
        var started = false
        var waiter: CheckedContinuation<Void, Never>?
    }

    private let state = Mutex(State())

    func wait() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state -> Bool in
                guard !state.started else {
                    return true
                }
                precondition(state.waiter == nil, "Task start gate has multiple waiters")
                state.waiter = continuation
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func start() {
        let waiter = state.withLock { state -> CheckedContinuation<Void, Never>? in
            guard !state.started else {
                return nil
            }
            state.started = true
            let waiter = state.waiter
            state.waiter = nil
            return waiter
        }
        waiter?.resume()
    }
}
