import Synchronization

final class ActorTaskStartGate: Sendable {
    private struct State: Sendable {
        var started = false
        var waiters: [CheckedContinuation<Void, Never>] = []
    }

    private let state = Mutex(State())

    func wait() async {
        await withCheckedContinuation { continuation in
            let resumeImmediately = state.withLock { state in
                guard !state.started else {
                    return true
                }
                state.waiters.append(continuation)
                return false
            }
            if resumeImmediately {
                continuation.resume()
            }
        }
    }

    func start() {
        let waiters = state.withLock { state -> [CheckedContinuation<Void, Never>] in
            guard !state.started else {
                return []
            }
            state.started = true
            let waiters = state.waiters
            state.waiters.removeAll(keepingCapacity: false)
            return waiters
        }
        for waiter in waiters {
            waiter.resume()
        }
    }
}
