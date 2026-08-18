#if SWIFTWEB_ACTORS
import ActorSystemCore

/// Hosting capability for attaching an authenticated duplex actor channel.
/// Transport lifecycle remains exclusively owned by `ActorSystemCore`.
package protocol SwiftWebActorChannelAttaching: Sendable {
    func attach(
        _ channel: any SwiftWebActorBinaryChannel,
        metadata: ActorByteBuffer
    ) async throws
}
#endif
