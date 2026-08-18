#if SWIFTWEB_ACTORS
import ActorSystemCore

/// Hosting capability for submitting one authenticated request/reply frame.
/// Transport lifecycle remains exclusively owned by `ActorSystemCore`.
package protocol SwiftWebActorRequestSubmitting: Sendable {
    func submit(
        _ frame: ActorFrame,
        metadata: ActorByteBuffer,
        peerIdentity: ActorByteBuffer,
        authorizationIdentity: ActorByteBuffer?
    ) async throws -> ActorFrame?
}
#endif
