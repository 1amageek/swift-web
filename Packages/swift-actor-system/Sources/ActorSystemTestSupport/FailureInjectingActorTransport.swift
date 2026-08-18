import ActorSystemCore
import Synchronization

public final class FailureInjectingActorTransport: ActorTransport, Sendable {
    public enum FailurePoint: Hashable, Sendable {
        case start
        case send
        case stream
    }

    private let failurePoint: FailurePoint
    public let incoming: AsyncThrowingStream<ActorInboundFrame, Error>
    private let continuation: AsyncThrowingStream<ActorInboundFrame, Error>.Continuation
    private let stopped = Mutex(false)

    public init(failurePoint: FailurePoint) {
        self.failurePoint = failurePoint
        let stream = AsyncThrowingStream<ActorInboundFrame, Error>.makeStream()
        self.incoming = stream.stream
        self.continuation = stream.continuation
    }

    public func start() async throws {
        if failurePoint == .start {
            throw ActorSystemError.transportClosed
        }
        if failurePoint == .stream {
            continuation.finish(throwing: ActorSystemError.transportClosed)
        }
    }

    public func send(_ frame: ActorFrame, to endpoint: ActorEndpoint) async throws {
        if failurePoint == .send {
            throw ActorSystemError.transportClosed
        }
    }

    public func shutdown() async {
        let shouldFinish = stopped.withLock { stopped -> Bool in
            guard !stopped else { return false }
            stopped = true
            return true
        }
        if shouldFinish {
            continuation.finish()
        }
    }
}
