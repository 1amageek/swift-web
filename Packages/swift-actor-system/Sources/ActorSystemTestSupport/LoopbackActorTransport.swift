import ActorSystemCore
import Synchronization

public final class LoopbackActorTransport: ActorTransport, Sendable {
    private struct Peer: Sendable {
        let transportID: ActorTransportID
        let endpoint: ActorEndpoint
        let yield: @Sendable (ActorInboundFrame) throws -> Void
    }

    private struct State: Sendable {
        var started = false
        var stopped = false
        var peer: Peer?
    }

    public let transportID: ActorTransportID
    public let endpoint: ActorEndpoint
    public let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let continuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let state = Mutex(State())

    public init(transportID: ActorTransportID, endpoint: ActorEndpoint) {
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream(
            bufferingPolicy: .bufferingOldest(1_024)
        )
        self.transportID = transportID
        self.endpoint = endpoint
        self.incoming = stream.stream
        self.continuation = stream.continuation
    }

    public func connect(to peer: LoopbackActorTransport) throws {
        try state.withLock { state in
            guard state.peer == nil, !state.started, !state.stopped else {
                throw ActorSystemError.alreadyStarted
            }
            state.peer = Peer(
                transportID: peer.transportID,
                endpoint: peer.endpoint,
                yield: { [peerContinuation = peer.continuation] frame in
                    switch peerContinuation.yield(frame) {
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
            )
        }
    }

    public func start() async throws {
        try state.withLock { state in
            guard !state.started, !state.stopped else {
                throw ActorSystemError.alreadyStarted
            }
            guard state.peer != nil else {
                throw ActorSystemError.transportUnavailable(transportID)
            }
            state.started = true
        }
    }

    public func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        let peer = try state.withLock { state -> Peer in
            guard state.started, !state.stopped, let peer = state.peer else {
                throw ActorSystemError.transportClosed
            }
            return peer
        }
        guard endpoint == peer.endpoint else {
            throw ActorSystemError.transportUnavailable(transportID)
        }
        try peer.yield(
            ActorInboundFrame(
                frame: frame,
                transport: peer.transportID,
                replyEndpoint: self.endpoint
            )
        )
    }

    public func shutdown() async {
        let shouldFinish = state.withLock { state -> Bool in
            guard !state.stopped else {
                return false
            }
            state.stopped = true
            state.started = false
            state.peer = nil
            return true
        }
        if shouldFinish {
            continuation.finish()
        }
    }
}
