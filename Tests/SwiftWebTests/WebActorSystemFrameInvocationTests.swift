import ActorSystemCore
@testable import SwiftWebActors
import Testing

@Suite
struct WebActorSystemFrameInvocationTests {
    @Test
    func hostingBoundaryPreservesBinaryFrameAndInvocationContext() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(
                ActorSessionID(80)
            )
        )
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPendingRequests: 2,
            maximumBufferedFrames: 2,
            maximumPeerEndpoints: 2
        )
        let actorSystem = try WebActorSystem(
            transports: [.swiftWebHTTP: transport],
            configuration: configuration
        )
        try await transport.start()

        let callID = ActorCallID(session: ActorSessionID(81), sequence: 1)
        let requestFrame = actorInvocationFrame(callID: callID)
        let encodedRequest = try actorSystem.frameCodec.encode(requestFrame)
        let invocation = Task {
            try await actorSystem.invokeActorFrame(
                encodedRequest,
                context: SwiftWebActorInvocationContext(
                    principalID: "calendar-page",
                    sessionID: "calendar-request"
                )
            )
        }

        var iterator = transport.incoming.makeAsyncIterator()
        let inbound = try #require(try await iterator.next())
        #expect(inbound.frame == requestFrame)
        let context = try SwiftWebActorInvocationContextCodec().decode(inbound.metadata)
        #expect(context.principalID == "calendar-page")
        #expect(context.sessionID == "calendar-request")

        let resultFrame = ActorFrame.result(
            ActorResultFrame(
                callID: callID,
                outcome: .success(
                    ActorInvocationResult(payload: ActorByteBuffer([0xCA, 0x1E]))
                )
            )
        )
        try await transport.send(resultFrame, to: inbound.replyEndpoint)
        let encodedResult = try #require(try await invocation.value)
        #expect(try actorSystem.frameCodec.decode(encodedResult) == resultFrame)

        await transport.shutdown()
    }

    @Test
    func hostingBoundaryRejectsMissingPeerIdentityBeforeAdmission() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(
                ActorSessionID(88)
            )
        )
        let transport = try SwiftWebRequestReplyActorTransport()
        let actorSystem = try WebActorSystem(
            transports: [.swiftWebHTTP: transport],
            configuration: configuration
        )
        let frame = actorInvocationFrame(
            callID: ActorCallID(session: ActorSessionID(82), sequence: 1)
        )

        await #expect(throws: ActorSystemError.self) {
            _ = try await actorSystem.invokeActorFrame(
                actorSystem.frameCodec.encode(frame),
                context: SwiftWebActorInvocationContext()
            )
        }
    }

    @Test
    func hostingBoundaryRejectsAnInvocationForAnotherDurableIdentity() async throws {
        let configuration = ActorSystemConfiguration(
            sessionIdentitySource: FixedActorSessionIdentitySource(
                ActorSessionID(89)
            )
        )
        let transport = try SwiftWebRequestReplyActorTransport()
        let actorSystem = try WebActorSystem(
            transports: [.swiftWebHTTP: transport],
            configuration: configuration
        )
        let frame = actorInvocationFrame(
            callID: ActorCallID(session: ActorSessionID(83), sequence: 1)
        )

        await #expect(throws: ActorSystemError.unauthorized) {
            _ = try await actorSystem.invokeActorFrame(
                actorSystem.frameCodec.encode(frame),
                context: SwiftWebActorInvocationContext(
                    peerID: "calendar-page",
                    hostedActorIdentity: "another-database"
                )
            )
        }
    }

    private func actorInvocationFrame(callID: ActorCallID) -> ActorFrame {
        .invocation(
            ActorInvocationFrame(
                callID: callID,
                invocation: ActorInvocation(
                    recipient: ActorAddress(
                        type: ActorTypeID(high: 83, low: 84),
                        identity: "calendar-database"
                    ),
                    method: ActorMethodID(85),
                    schemaFingerprint: ActorSchemaFingerprint(high: 86, low: 87),
                    payload: ActorByteBuffer([0x01, 0x02])
                ),
                remainingTimeoutNanoseconds: nil
            )
        )
    }
}
