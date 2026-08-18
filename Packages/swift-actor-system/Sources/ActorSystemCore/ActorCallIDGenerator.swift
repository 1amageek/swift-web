import Synchronization

final class ActorCallIDGenerator: Sendable {
    private struct State: Sendable {
        var session: ActorSessionID?
        var nextSequence: UInt64 = 0
    }

    private let state = Mutex(State())

    func activate(session: ActorSessionID) {
        state.withLock { state in
            state.session = session
            state.nextSequence = 0
        }
    }

    func next() throws -> ActorCallID {
        try state.withLock { state in
            guard let session = state.session else {
                throw ActorSystemError.notStarted
            }
            guard state.nextSequence < UInt64.max else {
                throw ActorSystemError.callSequenceExhausted
            }
            state.nextSequence += 1
            return ActorCallID(session: session, sequence: state.nextSequence)
        }
    }
}
