import Synchronization

final class PendingCallRegistry: Sendable {
    private struct Entry: Sendable {
        let transport: ActorTransportID
        let endpoint: ActorEndpoint
        let continuation: CheckedContinuation<ActorInvocationOutcome, Error>
        var timeoutTask: Task<Void, Never>?
    }

    private struct State: Sendable {
        var entries: [ActorCallID: Entry] = [:]
    }

    private let maximumCount: Int
    private let state = Mutex(State())

    init(maximumCount: Int) {
        self.maximumCount = maximumCount
    }

    func register(
        callID: ActorCallID,
        transport: ActorTransportID,
        endpoint: ActorEndpoint,
        continuation: CheckedContinuation<ActorInvocationOutcome, Error>
    ) throws {
        try state.withLock { state in
            guard state.entries.count < maximumCount else {
                throw ActorSystemError.overloaded
            }
            guard state.entries[callID] == nil else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation("Duplicate pending call identifier")
                )
            }
            state.entries[callID] = Entry(
                transport: transport,
                endpoint: endpoint,
                continuation: continuation,
                timeoutTask: nil
            )
        }
    }

    func installTimeout(_ task: Task<Void, Never>, for callID: ActorCallID) {
        let shouldCancel = state.withLock { state in
            guard var entry = state.entries[callID] else {
                return true
            }
            entry.timeoutTask = task
            state.entries[callID] = entry
            return false
        }
        if shouldCancel {
            task.cancel()
        }
    }

    @discardableResult
    func complete(
        callID: ActorCallID,
        from transport: ActorTransportID,
        endpoint: ActorEndpoint,
        outcome: ActorInvocationOutcome
    ) -> Bool {
        let entry = state.withLock { state -> Entry? in
            guard state.entries[callID]?.transport == transport,
                  state.entries[callID]?.endpoint == endpoint
            else {
                return nil
            }
            return state.entries.removeValue(forKey: callID)
        }
        guard let entry else {
            return false
        }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(returning: outcome)
        return true
    }

    @discardableResult
    func fail(callID: ActorCallID, error: any Error) -> Bool {
        let entry = state.withLock { state in
            state.entries.removeValue(forKey: callID)
        }
        guard let entry else {
            return false
        }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
        return true
    }

    @discardableResult
    func timeout(callID: ActorCallID) -> Bool {
        let entry = state.withLock { state in
            state.entries.removeValue(forKey: callID)
        }
        guard let entry else {
            return false
        }
        entry.continuation.resume(throwing: ActorSystemError.timeout)
        return true
    }

    @discardableResult
    func fail(
        callID: ActorCallID,
        from transport: ActorTransportID,
        endpoint: ActorEndpoint,
        error: any Error
    ) -> Bool {
        let entry = state.withLock { state -> Entry? in
            guard state.entries[callID]?.transport == transport,
                  state.entries[callID]?.endpoint == endpoint
            else {
                return nil
            }
            return state.entries.removeValue(forKey: callID)
        }
        guard let entry else {
            return false
        }
        entry.timeoutTask?.cancel()
        entry.continuation.resume(throwing: error)
        return true
    }

    func failCalls(using transport: ActorTransportID, error: any Error) {
        let entries = state.withLock { state -> [Entry] in
            let matchingIDs = state.entries.compactMap { callID, entry in
                entry.transport == transport ? callID : nil
            }
            return matchingIDs.compactMap { state.entries.removeValue(forKey: $0) }
        }
        for entry in entries {
            entry.timeoutTask?.cancel()
            entry.continuation.resume(throwing: error)
        }
    }

    func failCalls(
        using transport: ActorTransportID,
        endpoint: ActorEndpoint,
        error: any Error
    ) {
        let entries = state.withLock { state -> [Entry] in
            let matchingIDs = state.entries.compactMap { callID, entry in
                entry.transport == transport && entry.endpoint == endpoint
                    ? callID
                    : nil
            }
            return matchingIDs.compactMap { state.entries.removeValue(forKey: $0) }
        }
        for entry in entries {
            entry.timeoutTask?.cancel()
            entry.continuation.resume(throwing: error)
        }
    }

    func failAll(error: any Error) {
        let entries = state.withLock { state -> [Entry] in
            let removed = Array(state.entries.values)
            state.entries.removeAll(keepingCapacity: false)
            return removed
        }
        for entry in entries {
            entry.timeoutTask?.cancel()
            entry.continuation.resume(throwing: error)
        }
    }
}
