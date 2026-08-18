#if SWIFTWEB_ACTORS
import ActorSystemCore

/// The hosting-only operations provided by installed transport capabilities.
///
/// This capability intentionally does not expose `ActorTransport`, so hosting
/// adapters cannot start, stop, send through, or otherwise manage transports.
/// `ActorSystemCore` remains the sole transport lifecycle owner.
package struct SwiftWebActorHostingTransportCapability: Sendable {
    private let submitRequest: (@Sendable (
        ActorFrame,
        ActorByteBuffer,
        ActorByteBuffer,
        ActorByteBuffer?
    ) async throws -> ActorFrame?)?
    private let attachChannel: (@Sendable (
        any SwiftWebActorBinaryChannel,
        ActorByteBuffer
    ) async throws -> Void)?

    package init(transports: [ActorTransportID: any ActorTransport]) {
        if let transport = transports[.swiftWebHTTP]
            as? any SwiftWebActorRequestSubmitting {
            self.submitRequest = { frame, metadata, peerIdentity, authorizationIdentity in
                try await transport.submit(
                    frame,
                    metadata: metadata,
                    peerIdentity: peerIdentity,
                    authorizationIdentity: authorizationIdentity
                )
            }
        } else {
            self.submitRequest = nil
        }

        if let transport = transports[.swiftWebWebSocket]
            as? any SwiftWebActorChannelAttaching {
            self.attachChannel = { channel, metadata in
                try await transport.attach(channel, metadata: metadata)
            }
        } else {
            self.attachChannel = nil
        }
    }

    package var acceptsWebSocketChannels: Bool {
        attachChannel != nil
    }

    package func submit(
        _ frame: ActorFrame,
        metadata: ActorByteBuffer,
        peerIdentity: ActorByteBuffer,
        authorizationIdentity: ActorByteBuffer?
    ) async throws -> ActorFrame? {
        guard let submitRequest else {
            throw ActorSystemError.transportUnavailable(.swiftWebHTTP)
        }
        return try await submitRequest(
            frame,
            metadata,
            peerIdentity,
            authorizationIdentity
        )
    }

    package func attach(
        _ channel: any SwiftWebActorBinaryChannel,
        metadata: ActorByteBuffer
    ) async throws {
        guard let attachChannel else {
            throw ActorSystemError.transportUnavailable(.swiftWebWebSocket)
        }
        try await attachChannel(channel, metadata)
    }
}
#endif
