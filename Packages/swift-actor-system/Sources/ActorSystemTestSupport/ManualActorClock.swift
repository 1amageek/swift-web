import ActorSystemCore

public actor ManualActorClock: ActorClock {
    private struct Sleeper {
        let deadline: Duration
        let continuation: CheckedContinuation<Void, Error>
    }

    private var now: Duration = .zero
    private var sleepers: [UInt64: Sleeper] = [:]
    private var nextID: UInt64 = 0

    public init() {}

    public func sleep(for duration: Duration) async throws {
        guard duration > .zero else {
            return
        }
        nextID += 1
        let id = nextID
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                sleepers[id] = Sleeper(deadline: now + duration, continuation: continuation)
            }
        } onCancel: {
            Task { await self.cancel(id: id) }
        }
    }

    public func advance(by duration: Duration) {
        now += duration
        let readyIDs = sleepers.compactMap { id, sleeper in
            sleeper.deadline <= now ? id : nil
        }
        let ready = readyIDs.compactMap { sleepers.removeValue(forKey: $0) }
        for sleeper in ready {
            sleeper.continuation.resume()
        }
    }

    private func cancel(id: UInt64) {
        sleepers.removeValue(forKey: id)?.continuation.resume(
            throwing: CancellationError()
        )
    }
}
