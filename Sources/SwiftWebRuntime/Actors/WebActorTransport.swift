#if SWIFTWEB_ACTORS
@preconcurrency import ActorRuntime

public protocol WebActorTransport: Sendable {
    func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope
}
#endif
