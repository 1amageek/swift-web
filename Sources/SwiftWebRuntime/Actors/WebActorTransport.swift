#if SWIFTWEB_LEGACY_ACTORS
@preconcurrency import ActorSystemCompatibility

public protocol WebActorTransport: Sendable {
    func call(_ envelope: InvocationEnvelope) async throws -> ResponseEnvelope
}
#endif
