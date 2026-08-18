import ActorSystemCore
import Synchronization

/// Adapts authenticated request/reply exchanges to the frame transport SPI.
/// A bounded authorization-context registry gives equivalent requests the same
/// Core endpoint. A separate stable peer identity routes cancellation across
/// ordinary HTTP connection changes without weakening replay authorization.
public final class SwiftWebRequestReplyActorTransport: ActorTransport, Sendable {
    private enum Phase: Sendable, Equatable {
        case initialized
        case running
        case stopped
    }

    private struct RequestKey: Hashable, Sendable {
        let endpoint: ActorEndpoint
        let callID: ActorCallID
    }

    private struct CancellationKey: Hashable, Sendable {
        let peerIdentity: ActorByteBuffer
        let callID: ActorCallID
    }

    private struct PendingWaiter: Sendable {
        let id: UInt64
        let continuation: CheckedContinuation<ActorFrame, any Error>
        var invocationWasYielded: Bool
    }

    private struct DeferredCancellation: Sendable {
        let callID: ActorCallID
        let endpoint: ActorEndpoint
        var invocationWasYielded: Bool
    }

    private struct PeerRegistration: Sendable {
        let endpoint: ActorEndpoint
        var lastUse: UInt64
        var pendingWaiterCount: Int
    }

    private struct State: Sendable {
        var phase = Phase.initialized
        var nextEndpoint: UInt64 = 0
        var nextWaiterID: UInt64 = 0
        var nextUse: UInt64 = 0
        var peers: [ActorByteBuffer: PeerRegistration] = [:]
        var peerIdentitiesByEndpoint: [ActorEndpoint: ActorByteBuffer] = [:]
        var pending: [RequestKey: [PendingWaiter]] = [:]
        var pendingWaiterCount = 0
        var cancellationKeyByRequest: [RequestKey: CancellationKey] = [:]
        var cancellationEndpoints: [CancellationKey: Set<ActorEndpoint>] = [:]
        var deferredCancellations: [UInt64: DeferredCancellation] = [:]
    }

    private struct FailedWaiter: Sendable {
        let continuation: CheckedContinuation<ActorFrame, any Error>
    }

    public let incoming: AsyncThrowingStream<ActorInboundFrame, any Error>
    private let incomingContinuation: AsyncThrowingStream<ActorInboundFrame, any Error>.Continuation
    private let state = Mutex(State())
    private let maximumPendingRequests: Int
    private let maximumPeerEndpoints: Int
    private let maximumPeerIdentityBytes: Int

    public init(
        maximumPendingRequests: Int = 1_024,
        maximumBufferedFrames: Int = 64,
        maximumPeerEndpoints: Int = 1_024,
        maximumPeerIdentityBytes: Int = 1_024
    ) throws {
        guard maximumPendingRequests > 0,
              maximumBufferedFrames > 0,
              maximumPeerEndpoints > 0,
              maximumPeerIdentityBytes > 0
        else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("HTTP actor transport configuration is invalid")
            )
        }
        let pair = AsyncThrowingStream<ActorInboundFrame, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(maximumBufferedFrames)
        )
        self.incoming = pair.stream
        self.incomingContinuation = pair.continuation
        self.maximumPendingRequests = maximumPendingRequests
        self.maximumPeerEndpoints = maximumPeerEndpoints
        self.maximumPeerIdentityBytes = maximumPeerIdentityBytes
    }

    public func start() async throws {
        try state.withLock { state in
            guard state.phase == .initialized else {
                throw ActorSystemError.alreadyStarted
            }
            state.phase = .running
        }
    }

    public func submit(
        _ frame: ActorFrame,
        metadata: ActorByteBuffer = ActorByteBuffer(),
        peerIdentity: ActorByteBuffer,
        authorizationIdentity: ActorByteBuffer? = nil
    ) async throws -> ActorFrame? {
        try validate(peerIdentity: peerIdentity)
        let endpointIdentity = authorizationIdentity ?? peerIdentity
        try validate(peerIdentity: endpointIdentity)
        guard metadata.count <= maximumPeerIdentityBytes else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("HTTP actor metadata exceeds its configured limit")
            )
        }
        switch frame {
        case .invocation(let invocation):
            let waiterID = try allocateWaiterID()
            return try await withTaskCancellationHandler {
                do {
                    return try await withCheckedThrowingContinuation { continuation in
                        let endpoint: ActorEndpoint
                        do {
                            endpoint = try register(
                                PendingWaiter(
                                    id: waiterID,
                                    continuation: continuation,
                                    invocationWasYielded: false
                                ),
                                callID: invocation.callID,
                                peerIdentity: peerIdentity,
                                endpointIdentity: endpointIdentity
                            )
                        } catch {
                            continuation.resume(throwing: error)
                            return
                        }
                        let wasCancelled = withUnsafeCurrentTask { task in
                            task?.isCancelled ?? false
                        }
                        if wasCancelled {
                            failWaiter(
                                id: waiterID,
                                callID: invocation.callID,
                                peerIdentity: peerIdentity,
                                endpointIdentity: endpointIdentity,
                                error: ActorSystemError.cancelled,
                                defersCancellation: true
                            )
                            return
                        }
                        let result = incomingContinuation.yield(
                            ActorInboundFrame(
                                frame: frame,
                                transport: .swiftWebHTTP,
                                replyEndpoint: endpoint,
                                metadata: metadata
                            )
                        )
                        switch result {
                        case .enqueued:
                            markInvocationYielded(
                                id: waiterID,
                                callID: invocation.callID,
                                endpointIdentity: endpointIdentity
                            )
                        case .dropped:
                            failWaiter(
                                id: waiterID,
                                callID: invocation.callID,
                                peerIdentity: peerIdentity,
                                endpointIdentity: endpointIdentity,
                                error: ActorSystemError.overloaded,
                                defersCancellation: false
                            )
                        case .terminated:
                            failWaiter(
                                id: waiterID,
                                callID: invocation.callID,
                                peerIdentity: peerIdentity,
                                endpointIdentity: endpointIdentity,
                                error: ActorSystemError.transportClosed,
                                defersCancellation: false
                            )
                        @unknown default:
                            failWaiter(
                                id: waiterID,
                                callID: invocation.callID,
                                peerIdentity: peerIdentity,
                                endpointIdentity: endpointIdentity,
                                error: ActorSystemError.transportClosed,
                                defersCancellation: false
                            )
                        }
                    }
                } catch {
                    emitDeferredCancellation(for: waiterID)
                    throw error
                }
            } onCancel: {
                failWaiter(
                    id: waiterID,
                    callID: invocation.callID,
                    peerIdentity: peerIdentity,
                    endpointIdentity: endpointIdentity,
                    error: ActorSystemError.cancelled,
                    defersCancellation: true
                )
            }
        case .cancellation(let callID):
            try requireRunning()
            let endpoints = cancellationEndpoints(
                for: callID,
                peerIdentity: peerIdentity
            )
            guard !endpoints.isEmpty else {
                return nil
            }
            var firstFailure: (any Error)?
            for endpoint in endpoints {
                do {
                    try yieldControlFrame(
                        frame,
                        endpoint: endpoint,
                        metadata: metadata
                    )
                } catch {
                    if firstFailure == nil {
                        firstFailure = error
                    }
                }
            }
            if let firstFailure {
                throw firstFailure
            }
            return nil
        case .hello:
            let endpoint = try state.withLock { state in
                try endpoint(for: endpointIdentity, state: &state)
            }
            try yieldControlFrame(
                frame,
                endpoint: endpoint,
                metadata: metadata
            )
            return nil
        case .result:
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("HTTP request transport cannot accept a result request")
            )
        }
    }

    public func send(
        _ frame: ActorFrame,
        to endpoint: ActorEndpoint
    ) async throws {
        guard case .result(let result) = frame else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("HTTP request transport can only send result replies")
            )
        }
        let continuation = try state.withLock { state -> CheckedContinuation<ActorFrame, any Error> in
            guard state.phase == .running,
                  let peerIdentity = state.peerIdentitiesByEndpoint[endpoint],
                  var peer = state.peers[peerIdentity],
                  peer.pendingWaiterCount > 0,
                  state.pendingWaiterCount > 0
            else {
                throw ActorSystemError.transportClosed
            }
            let key = RequestKey(endpoint: endpoint, callID: result.callID)
            guard var waiters = state.pending[key], let waiter = waiters.popLast() else {
                throw ActorSystemError.transportClosed
            }
            let use = nextUse(state: &state)
            if waiters.isEmpty {
                state.pending[key] = nil
                removeCancellationEndpoint(for: key, state: &state)
            } else {
                state.pending[key] = waiters
            }
            peer.pendingWaiterCount -= 1
            peer.lastUse = use
            state.peers[peerIdentity] = peer
            state.pendingWaiterCount -= 1
            return waiter.continuation
        }
        continuation.resume(returning: frame)
    }

    public func shutdown() async {
        let continuations = state.withLock { state -> [CheckedContinuation<ActorFrame, any Error>] in
            guard state.phase != .stopped else {
                return []
            }
            state.phase = .stopped
            let continuations = state.pending.values
                .flatMap { waiters in
                    waiters.map { waiter in waiter.continuation }
                }
            state.pending.removeAll(keepingCapacity: false)
            state.pendingWaiterCount = 0
            state.cancellationKeyByRequest.removeAll(keepingCapacity: false)
            state.cancellationEndpoints.removeAll(keepingCapacity: false)
            state.deferredCancellations.removeAll(keepingCapacity: false)
            state.peers.removeAll(keepingCapacity: false)
            state.peerIdentitiesByEndpoint.removeAll(keepingCapacity: false)
            return continuations
        }
        incomingContinuation.finish()
        for continuation in continuations {
            continuation.resume(throwing: ActorSystemError.transportClosed)
        }
    }

    private func allocateWaiterID() throws -> UInt64 {
        try state.withLock { state in
            guard state.phase == .running else {
                throw ActorSystemError.transportClosed
            }
            guard state.nextWaiterID < UInt64.max else {
                throw ActorSystemError.callSequenceExhausted
            }
            state.nextWaiterID += 1
            return state.nextWaiterID
        }
    }

    private func register(
        _ waiter: PendingWaiter,
        callID: ActorCallID,
        peerIdentity: ActorByteBuffer,
        endpointIdentity: ActorByteBuffer
    ) throws -> ActorEndpoint {
        try state.withLock { state in
            guard state.phase == .running else {
                throw ActorSystemError.transportClosed
            }
            guard state.pendingWaiterCount < maximumPendingRequests,
                  state.deferredCancellations.count
                    < maximumPendingRequests - state.pendingWaiterCount
            else {
                throw ActorSystemError.overloaded
            }
            let endpoint = try endpoint(for: endpointIdentity, state: &state)
            guard var peer = state.peers[endpointIdentity] else {
                throw ActorSystemError.transportClosed
            }
            let key = RequestKey(endpoint: endpoint, callID: callID)
            let cancellationKey = CancellationKey(
                peerIdentity: peerIdentity,
                callID: callID
            )
            if let existing = state.cancellationKeyByRequest[key],
               existing != cancellationKey {
                throw ActorSystemError.unauthorized
            }
            state.pending[key, default: []].append(waiter)
            state.cancellationKeyByRequest[key] = cancellationKey
            state.cancellationEndpoints[cancellationKey, default: []]
                .insert(endpoint)
            peer.pendingWaiterCount += 1
            state.peers[endpointIdentity] = peer
            state.pendingWaiterCount += 1
            return endpoint
        }
    }

    private func endpoint(
        for endpointIdentity: ActorByteBuffer,
        state: inout State
    ) throws -> ActorEndpoint {
        guard state.phase == .running else {
            throw ActorSystemError.transportClosed
        }
        if var existing = state.peers[endpointIdentity] {
            existing.lastUse = nextUse(state: &state)
            state.peers[endpointIdentity] = existing
            return existing.endpoint
        }
        if state.peers.count >= maximumPeerEndpoints {
            guard let evicted = state.peers
                .filter({ $0.value.pendingWaiterCount == 0 })
                .min(by: { $0.value.lastUse < $1.value.lastUse })
            else {
                throw ActorSystemError.overloaded
            }
            state.peers[evicted.key] = nil
            state.peerIdentitiesByEndpoint[evicted.value.endpoint] = nil
        }
        guard state.nextEndpoint < UInt64.max else {
            throw ActorSystemError.callSequenceExhausted
        }
        state.nextEndpoint += 1
        let endpoint = ActorEndpoint("swiftweb.http.peer.\(state.nextEndpoint)")
        let registration = PeerRegistration(
            endpoint: endpoint,
            lastUse: nextUse(state: &state),
            pendingWaiterCount: 0
        )
        state.peers[endpointIdentity] = registration
        state.peerIdentitiesByEndpoint[endpoint] = endpointIdentity
        return endpoint
    }

    private func nextUse(state: inout State) -> UInt64 {
        if state.nextUse == UInt64.max {
            let orderedPeers = state.peers.sorted { left, right in
                if left.value.lastUse == right.value.lastUse {
                    return left.value.endpoint.transportSpecificAddress
                        < right.value.endpoint.transportSpecificAddress
                }
                return left.value.lastUse < right.value.lastUse
            }
            for (index, entry) in orderedPeers.enumerated() {
                var peer = entry.value
                peer.lastUse = UInt64(index + 1)
                state.peers[entry.key] = peer
            }
            state.nextUse = UInt64(orderedPeers.count)
        }
        state.nextUse += 1
        return state.nextUse
    }

    private func cancellationEndpoints(
        for callID: ActorCallID,
        peerIdentity: ActorByteBuffer
    ) -> [ActorEndpoint] {
        state.withLock { state in
            guard state.phase == .running else {
                return []
            }
            return Array(
                state.cancellationEndpoints[
                    CancellationKey(
                        peerIdentity: peerIdentity,
                        callID: callID
                    )
                ] ?? []
            )
            .sorted {
                $0.transportSpecificAddress < $1.transportSpecificAddress
            }
        }
    }

    private func failWaiter(
        id: UInt64,
        callID: ActorCallID,
        peerIdentity: ActorByteBuffer,
        endpointIdentity: ActorByteBuffer,
        error: any Error,
        defersCancellation: Bool
    ) {
        let failed = state.withLock { state -> FailedWaiter? in
            guard let peer = state.peers[endpointIdentity] else {
                return nil
            }
            let key = RequestKey(endpoint: peer.endpoint, callID: callID)
            guard var waiters = state.pending[key],
                  let index = waiters.firstIndex(where: { $0.id == id }),
                  state.cancellationKeyByRequest[key]?.peerIdentity == peerIdentity,
                  peer.pendingWaiterCount > 0,
                  state.pendingWaiterCount > 0
            else {
                return nil
            }
            let waiter = waiters.remove(at: index)
            if waiters.isEmpty {
                state.pending[key] = nil
                removeCancellationEndpoint(for: key, state: &state)
            } else {
                state.pending[key] = waiters
            }
            var updatedPeer = peer
            updatedPeer.pendingWaiterCount -= 1
            state.peers[endpointIdentity] = updatedPeer
            state.pendingWaiterCount -= 1
            if defersCancellation, waiters.isEmpty {
                state.deferredCancellations[id] = DeferredCancellation(
                    callID: callID,
                    endpoint: peer.endpoint,
                    invocationWasYielded: waiter.invocationWasYielded
                )
            }
            return FailedWaiter(continuation: waiter.continuation)
        }
        guard let failed else {
            return
        }
        failed.continuation.resume(throwing: error)
    }

    private func markInvocationYielded(
        id: UInt64,
        callID: ActorCallID,
        endpointIdentity: ActorByteBuffer
    ) {
        state.withLock { state in
            if let peer = state.peers[endpointIdentity] {
                let key = RequestKey(endpoint: peer.endpoint, callID: callID)
                if var waiters = state.pending[key],
                   let index = waiters.firstIndex(where: { $0.id == id }) {
                    waiters[index].invocationWasYielded = true
                    state.pending[key] = waiters
                    return
                }
            }
            if var cancellation = state.deferredCancellations[id] {
                cancellation.invocationWasYielded = true
                state.deferredCancellations[id] = cancellation
            }
        }
    }

    private func emitDeferredCancellation(for waiterID: UInt64) {
        let cancellation = state.withLock { state in
            state.deferredCancellations.removeValue(forKey: waiterID)
        }
        guard let cancellation, cancellation.invocationWasYielded else {
            return
        }
        let result = incomingContinuation.yield(
            ActorInboundFrame(
                frame: .cancellation(cancellation.callID),
                transport: .swiftWebHTTP,
                replyEndpoint: cancellation.endpoint
            )
        )
        switch result {
        case .enqueued:
            return
        case .dropped, .terminated:
            // The waiter has already observed cancellation. Control-frame
            // propagation is best effort when the bounded transport is full
            // or is already closed.
            return
        @unknown default:
            return
        }
    }

    private func removeCancellationEndpoint(
        for requestKey: RequestKey,
        state: inout State
    ) {
        guard let cancellationKey = state.cancellationKeyByRequest.removeValue(
            forKey: requestKey
        ) else {
            return
        }
        state.cancellationEndpoints[cancellationKey]?.remove(requestKey.endpoint)
        if state.cancellationEndpoints[cancellationKey]?.isEmpty == true {
            state.cancellationEndpoints[cancellationKey] = nil
        }
    }

    private func yieldControlFrame(
        _ frame: ActorFrame,
        endpoint: ActorEndpoint,
        metadata: ActorByteBuffer
    ) throws {
        let result = incomingContinuation.yield(
            ActorInboundFrame(
                frame: frame,
                transport: .swiftWebHTTP,
                replyEndpoint: endpoint,
                metadata: metadata
            )
        )
        switch result {
        case .enqueued:
            return
        case .dropped:
            throw ActorSystemError.overloaded
        case .terminated:
            throw ActorSystemError.transportClosed
        @unknown default:
            throw ActorSystemError.transportClosed
        }
    }

    private func validate(peerIdentity: ActorByteBuffer) throws {
        guard !peerIdentity.isEmpty,
              peerIdentity.count <= maximumPeerIdentityBytes
        else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("HTTP actor peer identity is invalid")
            )
        }
    }

    private func requireRunning() throws {
        try state.withLock { state in
            guard state.phase == .running else {
                throw ActorSystemError.transportClosed
            }
        }
    }
}

#if SWIFTWEB_ACTORS
extension SwiftWebRequestReplyActorTransport: SwiftWebActorRequestSubmitting {}
#endif
