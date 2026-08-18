actor ActorInboundScheduler {
    typealias Reply = @Sendable (ActorInvocationOutcome) async -> Void

    private struct CallKey: Hashable, Sendable {
        let transport: ActorTransportID
        let endpoint: ActorEndpoint
        let callID: ActorCallID
    }

    private struct ActiveCall {
        let task: Task<Void, Never>
        var replies: [Reply]
    }

    private struct ReplayCall {
        let transport: ActorTransportID
        let endpoint: ActorEndpoint
        let task: Task<Void, Never>
    }

    private let maximumConcurrentCalls: Int
    private let maximumRetainedResults: Int
    private let owner: ActorOwnedTaskOwner
    private var accepting = true
    private var activeCalls: [CallKey: ActiveCall] = [:]
    private var replayCalls: [UInt64: ReplayCall] = [:]
    private var nextReplayID: UInt64 = 0
    private var completedResults: [CallKey: ActorInvocationOutcome] = [:]
    private var completedOrder: [CallKey] = []

    init(
        maximumConcurrentCalls: Int,
        maximumRetainedResults: Int,
        owner: ActorOwnedTaskOwner = ActorOwnedTaskOwner()
    ) {
        self.maximumConcurrentCalls = maximumConcurrentCalls
        self.maximumRetainedResults = maximumRetainedResults
        self.owner = owner
    }

    func submit(
        callID: ActorCallID,
        transport: ActorTransportID,
        endpoint: ActorEndpoint,
        reply: @escaping Reply,
        operation: @escaping @Sendable () async -> ActorInvocationOutcome
    ) throws {
        guard accepting else {
            throw ActorSystemError.shuttingDown
        }
        let key = CallKey(
            transport: transport,
            endpoint: endpoint,
            callID: callID
        )
        if let completed = completedResults[key] {
            guard activeCalls.count + replayCalls.count < maximumConcurrentCalls else {
                throw ActorSystemError.overloaded
            }
            if nextReplayID == UInt64.max {
                guard replayCalls.isEmpty else {
                    throw ActorSystemError.overloaded
                }
                nextReplayID = 0
            }
            nextReplayID += 1
            let replayID = nextReplayID
            let identity = ActorOwnedTaskIdentity(owner: owner, kind: .inbound)
            let task = Task {
                await ActorOwnedTaskContext.$current.withValue(identity) {
                    await reply(completed)
                    self.replayFinished(id: replayID)
                }
            }
            replayCalls[replayID] = ReplayCall(
                transport: transport,
                endpoint: endpoint,
                task: task
            )
            return
        }
        if var active = activeCalls[key] {
            guard active.replies.count < maximumConcurrentCalls else {
                throw ActorSystemError.overloaded
            }
            active.replies.append(reply)
            activeCalls[key] = active
            return
        }
        guard activeCalls.count + replayCalls.count < maximumConcurrentCalls else {
            throw ActorSystemError.overloaded
        }

        let identity = ActorOwnedTaskIdentity(owner: owner, kind: .inbound)
        let task = Task {
            await ActorOwnedTaskContext.$current.withValue(identity) {
                let outcome = await operation()
                await self.finished(key: key, outcome: outcome)
            }
        }
        activeCalls[key] = ActiveCall(task: task, replies: [reply])
    }

    func cancel(
        callID: ActorCallID,
        transport: ActorTransportID,
        endpoint: ActorEndpoint
    ) {
        activeCalls[
            CallKey(transport: transport, endpoint: endpoint, callID: callID)
        ]?.task.cancel()
    }

    func endpointClosed(
        transport: ActorTransportID,
        endpoint: ActorEndpoint
    ) async {
        let matchingKeys = activeCalls.keys.filter {
            $0.transport == transport && $0.endpoint == endpoint
        }
        let tasks = matchingKeys.compactMap {
            activeCalls.removeValue(forKey: $0)?.task
        }
        let replayIDs = replayCalls.compactMap { id, replay in
            replay.transport == transport && replay.endpoint == endpoint ? id : nil
        }
        let replayTasks = replayIDs.compactMap {
            replayCalls.removeValue(forKey: $0)?.task
        }
        completedResults = completedResults.filter {
            !($0.key.transport == transport && $0.key.endpoint == endpoint)
        }
        completedOrder.removeAll {
            $0.transport == transport && $0.endpoint == endpoint
        }
        for task in tasks + replayTasks {
            task.cancel()
        }
        for task in tasks + replayTasks {
            await task.value
        }
    }

    func transportClosed(_ transport: ActorTransportID) async {
        let matchingKeys = activeCalls.keys.filter {
            $0.transport == transport
        }
        let tasks = matchingKeys.compactMap { activeCalls.removeValue(forKey: $0)?.task }
        let replayIDs = replayCalls.compactMap { id, replay in
            replay.transport == transport ? id : nil
        }
        let replayTasks = replayIDs.compactMap {
            replayCalls.removeValue(forKey: $0)?.task
        }
        completedResults = completedResults.filter {
            $0.key.transport != transport
        }
        completedOrder.removeAll {
            $0.transport == transport
        }
        for task in tasks + replayTasks {
            task.cancel()
        }
        for task in tasks + replayTasks {
            await task.value
        }
    }

    func stopAcceptingAndCancel() -> [Task<Void, Never>] {
        accepting = false
        let runningTasks = activeCalls.values.map { $0.task }
            + replayCalls.values.map { $0.task }
        activeCalls.removeAll(keepingCapacity: false)
        replayCalls.removeAll(keepingCapacity: false)
        completedResults.removeAll(keepingCapacity: false)
        completedOrder.removeAll(keepingCapacity: false)
        for task in runningTasks {
            task.cancel()
        }
        return runningTasks
    }

    private func finished(
        key: CallKey,
        outcome: ActorInvocationOutcome
    ) async {
        guard activeCalls[key] != nil else { return }
        retain(outcome, for: key)
        while var active = activeCalls[key] {
            let replies = active.replies
            active.replies.removeAll(keepingCapacity: false)
            activeCalls[key] = active
            for reply in replies {
                await reply(outcome)
            }
            guard activeCalls[key]?.replies.isEmpty == true else {
                continue
            }
            activeCalls[key] = nil
            return
        }
    }

    private func replayFinished(id: UInt64) {
        replayCalls[id] = nil
    }

    private func retain(
        _ outcome: ActorInvocationOutcome,
        for key: CallKey
    ) {
        guard maximumRetainedResults > 0 else {
            return
        }
        completedResults[key] = outcome
        completedOrder.append(key)
        while completedOrder.count > maximumRetainedResults {
            let expired = completedOrder.removeFirst()
            completedResults[expired] = nil
        }
    }
}
