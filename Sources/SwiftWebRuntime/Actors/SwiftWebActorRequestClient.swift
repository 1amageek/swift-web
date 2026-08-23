import ActorSystemCore

/// Host-owned client for one request/reply actor transport exchange.
///
/// Application code depends on distributed actor types. A platform adapter
/// installs this capability to bind encoded actor frames to its native request
/// primitive without exposing endpoints or credentials to the application.
@_spi(Hosting)
public protocol SwiftWebActorRequestClient: Sendable {
    func requestActorFrame(
        _ encodedFrame: ActorByteBuffer,
        to endpoint: ActorEndpoint,
        onDispatched: @escaping @Sendable () -> Void
    ) async throws -> ActorByteBuffer?

    func shutdown() async
}
