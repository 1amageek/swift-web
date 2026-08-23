#if SWIFTWEB_ACTORS
@_spi(Transport) import ActorSystemCore
import SwiftWebActors
import Synchronization
@_spi(Hosting) import SwiftWebHost

/// Adapts one authenticated host WebSocket connection to the transport-neutral
/// binary channel consumed by `SwiftWebWebSocketActorTransport`.
final class SwiftWebHostActorBinaryChannel: SwiftWebActorBinaryChannel, Sendable {
    private enum Phase: Sendable, Equatable {
        case initialized
        case running
        case stopped
    }

    nonisolated let endpoint: ActorEndpoint
    nonisolated let incoming: AsyncThrowingStream<ActorByteBuffer, any Error>

    private let incomingContinuation:
        AsyncThrowingStream<ActorByteBuffer, any Error>.Continuation
    private let socket: any WebSocketChannel
    private let maximumFrameBytes: Int
    private let phase = Mutex(Phase.initialized)

    init(
        endpoint: ActorEndpoint,
        socket: any WebSocketChannel,
        maximumFrameBytes: Int,
        maximumBufferedFrames: Int
    ) throws {
        guard maximumFrameBytes >= ActorFrameCodec.minimumFrameBytes else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket frame limit is invalid")
            )
        }
        guard maximumBufferedFrames > 0 else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket buffer limit is invalid")
            )
        }
        let pair = AsyncThrowingStream<ActorByteBuffer, any Error>.makeStream(
            bufferingPolicy: .bufferingOldest(maximumBufferedFrames)
        )
        self.endpoint = endpoint
        self.incoming = pair.stream
        self.incomingContinuation = pair.continuation
        self.socket = socket
        self.maximumFrameBytes = maximumFrameBytes
    }

    func start() async throws {
        try phase.withLock { phase in
            guard phase == .initialized else {
                throw ActorSystemError.alreadyStarted
            }
            phase = .running
        }
        socket.onBinary { [self] bytes in
            try receive(bytes)
        }
        await socket.onClose { [self] in
            finish()
        }
    }

    func send(_ bytes: ActorByteBuffer) async throws {
        guard bytes.count <= maximumFrameBytes else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket frame exceeds its limit")
            )
        }
        try requireRunning()
        if let retained = bytes.retainedStorage(as: SwiftWebActorBinaryStorage.self),
           case .webSocket(let source) = retained.storage.source {
            try await socket.send(source[retained.range])
        } else {
            try await socket.send(
                WebSocketBinaryBuffer(
                    storage: SwiftWebActorBinaryStorage(source: .actor(bytes))
                )
            )
        }
    }

    func shutdown() async {
        let shouldClose = phase.withLock { phase -> Bool in
            guard phase != .stopped else {
                return false
            }
            phase = .stopped
            return true
        }
        guard shouldClose else {
            return
        }
        incomingContinuation.finish()
        do {
            try await socket.close()
        } catch {
            // The stream is already terminated; the host owns socket diagnostics.
        }
    }

    private func receive(_ bytes: WebSocketBinaryBuffer) throws {
        try requireRunning()
        guard bytes.count <= maximumFrameBytes else {
            let error = ActorSystemError.invalidFrame(
                ActorProtocolViolation("Actor WebSocket frame exceeds its limit")
            )
            incomingContinuation.finish(throwing: error)
            throw error
        }
        let ownedBytes = ActorByteBuffer(
            storage: SwiftWebActorBinaryStorage(source: .webSocket(bytes))
        )
        switch incomingContinuation.yield(ownedBytes) {
        case .enqueued:
            return
        case .dropped:
            incomingContinuation.finish(throwing: ActorSystemError.overloaded)
            throw ActorSystemError.overloaded
        case .terminated:
            throw ActorSystemError.transportClosed
        @unknown default:
            throw ActorSystemError.transportClosed
        }
    }

    private func requireRunning() throws {
        try phase.withLock { phase in
            guard phase == .running else {
                throw ActorSystemError.transportClosed
            }
        }
    }

    private func finish() {
        let shouldFinish = phase.withLock { phase -> Bool in
            guard phase != .stopped else {
                return false
            }
            phase = .stopped
            return true
        }
        if shouldFinish {
            incomingContinuation.finish()
        }
    }
}
#endif
