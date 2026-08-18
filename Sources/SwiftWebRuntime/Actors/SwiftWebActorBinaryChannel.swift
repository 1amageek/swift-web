import ActorSystemCore

/// A single authenticated byte-oriented duplex link used by the WebSocket
/// actor transport. Socket ownership and authentication remain host-specific.
public protocol SwiftWebActorBinaryChannel: Sendable {
    var endpoint: ActorEndpoint { get }
    var incoming: AsyncThrowingStream<ActorByteBuffer, any Error> { get }

    func start() async throws
    func send(_ bytes: ActorByteBuffer) async throws
    func shutdown() async
}
