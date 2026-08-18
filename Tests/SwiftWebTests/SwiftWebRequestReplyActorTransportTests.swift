import ActorSystemCore
import SwiftWebActors
import Testing

@Suite
struct SwiftWebRequestReplyActorTransportTests {
    @Test
    func duplicateCallsFromOnePeerShareTheCoreEndpoint() async throws {
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPendingRequests: 4,
            maximumBufferedFrames: 4,
            maximumPeerEndpoints: 2
        )
        try await transport.start()
        let callID = ActorCallID(session: ActorSessionID(41), sequence: 1)
        let invocation = requestReplyInvocation(callID: callID)
        let peerIdentity = ActorByteBuffer([0x01])
        let first = Task {
            try await transport.submit(invocation, peerIdentity: peerIdentity)
        }
        let second = Task {
            try await transport.submit(invocation, peerIdentity: peerIdentity)
        }

        var iterator = transport.incoming.makeAsyncIterator()
        let firstInbound = try #require(try await iterator.next())
        let secondInbound = try #require(try await iterator.next())
        #expect(firstInbound.replyEndpoint == secondInbound.replyEndpoint)

        let result = ActorFrame.result(
            ActorResultFrame(
                callID: callID,
                outcome: .success(ActorInvocationResult())
            )
        )
        try await transport.send(result, to: firstInbound.replyEndpoint)
        try await transport.send(result, to: secondInbound.replyEndpoint)
        #expect(try await first.value == result)
        #expect(try await second.value == result)

        await transport.shutdown()
    }

    @Test
    func cancellingARequestUsesItsOriginalPeerEndpoint() async throws {
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPendingRequests: 2,
            maximumBufferedFrames: 2,
            maximumPeerEndpoints: 2
        )
        try await transport.start()
        let callID = ActorCallID(session: ActorSessionID(42), sequence: 1)
        let peerIdentity = ActorByteBuffer([0x02])
        let request = Task {
            try await transport.submit(
                requestReplyInvocation(callID: callID),
                peerIdentity: peerIdentity
            )
        }

        var iterator = transport.incoming.makeAsyncIterator()
        let invocation = try #require(try await iterator.next())
        request.cancel()
        let cancellation = try #require(try await iterator.next())

        #expect(cancellation.frame == .cancellation(callID))
        #expect(cancellation.replyEndpoint == invocation.replyEndpoint)
        do {
            _ = try await request.value
            Issue.record("A cancelled HTTP actor request must fail")
        } catch let error as ActorSystemError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Expected ActorSystemError.cancelled, got \(error)")
        }

        await transport.shutdown()
    }

    @Test
    func cancellationBeforeAdmissionDoesNotEmitAControlFrame() async throws {
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPendingRequests: 2,
            maximumBufferedFrames: 2,
            maximumPeerEndpoints: 2
        )
        try await transport.start()
        let gate = RequestReplyCancellationGate()
        let callID = ActorCallID(session: ActorSessionID(46), sequence: 1)
        let peerIdentity = ActorByteBuffer([0x06])
        let request = Task {
            await gate.wait()
            return try await transport.submit(
                requestReplyInvocation(callID: callID),
                peerIdentity: peerIdentity
            )
        }
        await gate.waitUntilBlocked()
        request.cancel()
        await gate.open()

        do {
            _ = try await request.value
            Issue.record("A request cancelled before admission must fail")
        } catch let error as ActorSystemError {
            #expect(error == .cancelled)
        } catch {
            Issue.record("Expected ActorSystemError.cancelled, got \(error)")
        }

        let hello = ActorFrame.hello(
            ActorHelloFrame(
                session: ActorSessionID(46),
                maximumWireVersion: ActorFrameCodec.wireVersion
            )
        )
        _ = try await transport.submit(hello, peerIdentity: peerIdentity)
        var iterator = transport.incoming.makeAsyncIterator()
        let firstInbound = try #require(try await iterator.next())
        #expect(firstInbound.frame == hello)

        await transport.shutdown()
    }

    @Test
    func cancellationCannotBorrowAnotherPeersEndpoint() async throws {
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPendingRequests: 2,
            maximumBufferedFrames: 4,
            maximumPeerEndpoints: 2
        )
        try await transport.start()
        let callID = ActorCallID(session: ActorSessionID(43), sequence: 1)
        let firstPeer = ActorByteBuffer([0x03])
        let secondPeer = ActorByteBuffer([0x04])
        let firstRequest = Task {
            try await transport.submit(
                requestReplyInvocation(callID: callID),
                metadata: ActorByteBuffer([0xA1]),
                peerIdentity: firstPeer
            )
        }
        let secondRequest = Task {
            try await transport.submit(
                requestReplyInvocation(callID: callID),
                metadata: ActorByteBuffer([0xB1]),
                peerIdentity: secondPeer
            )
        }

        var iterator = transport.incoming.makeAsyncIterator()
        let firstInbound = try #require(try await iterator.next())
        let secondInbound = try #require(try await iterator.next())
        let invocations = [firstInbound, secondInbound]
        let firstInvocation = try #require(
            invocations.first { $0.metadata == ActorByteBuffer([0xA1]) }
        )
        let secondInvocation = try #require(
            invocations.first { $0.metadata == ActorByteBuffer([0xB1]) }
        )
        _ = try await transport.submit(
            .cancellation(callID),
            peerIdentity: secondPeer
        )
        let cancellation = try #require(try await iterator.next())

        #expect(cancellation.replyEndpoint == secondInvocation.replyEndpoint)
        #expect(cancellation.replyEndpoint != firstInvocation.replyEndpoint)

        let result = ActorFrame.result(
            ActorResultFrame(
                callID: callID,
                outcome: .success(ActorInvocationResult())
            )
        )
        try await transport.send(result, to: firstInvocation.replyEndpoint)
        try await transport.send(result, to: secondInvocation.replyEndpoint)
        #expect(try await firstRequest.value == result)
        #expect(try await secondRequest.value == result)
        await transport.shutdown()
    }

    @Test
    func stablePeerCancellationReachesEveryActiveAuthorizationEndpoint() async throws {
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPendingRequests: 2,
            maximumBufferedFrames: 6,
            maximumPeerEndpoints: 2
        )
        try await transport.start()
        let callID = ActorCallID(session: ActorSessionID(45), sequence: 1)
        let peerIdentity = ActorByteBuffer([0x05])
        let first = Task {
            try await transport.submit(
                requestReplyInvocation(callID: callID),
                peerIdentity: peerIdentity,
                authorizationIdentity: ActorByteBuffer([0xC1])
            )
        }
        let second = Task {
            try await transport.submit(
                requestReplyInvocation(callID: callID),
                peerIdentity: peerIdentity,
                authorizationIdentity: ActorByteBuffer([0xC2])
            )
        }

        var iterator = transport.incoming.makeAsyncIterator()
        let firstInvocation = try #require(try await iterator.next())
        let secondInvocation = try #require(try await iterator.next())
        #expect(firstInvocation.replyEndpoint != secondInvocation.replyEndpoint)
        _ = try await transport.submit(
            .cancellation(callID),
            peerIdentity: peerIdentity,
            authorizationIdentity: ActorByteBuffer([0xC3])
        )
        let firstCancellation = try #require(try await iterator.next())
        let secondCancellation = try #require(try await iterator.next())
        #expect(
            Set([firstCancellation.replyEndpoint, secondCancellation.replyEndpoint])
                == Set([firstInvocation.replyEndpoint, secondInvocation.replyEndpoint])
        )

        let result = ActorFrame.result(
            ActorResultFrame(
                callID: callID,
                outcome: .success(ActorInvocationResult())
            )
        )
        try await transport.send(result, to: firstInvocation.replyEndpoint)
        try await transport.send(result, to: secondInvocation.replyEndpoint)
        #expect(try await first.value == result)
        #expect(try await second.value == result)
        await transport.shutdown()
    }

    @Test
    func invalidBoundsFailAtConstruction() {
        #expect(throws: ActorSystemError.self) {
            _ = try SwiftWebRequestReplyActorTransport(
                maximumPendingRequests: 0
            )
        }
    }

    @Test
    func oversizedMetadataFailsBeforeAdmission() async throws {
        let transport = try SwiftWebRequestReplyActorTransport(
            maximumPeerIdentityBytes: 1
        )
        try await transport.start()

        await #expect(throws: ActorSystemError.self) {
            _ = try await transport.submit(
                .hello(
                    ActorHelloFrame(
                        session: ActorSessionID(47),
                        maximumWireVersion: ActorFrameCodec.wireVersion
                    )
                ),
                metadata: ActorByteBuffer([0x01, 0x02]),
                peerIdentity: ActorByteBuffer([0x01])
            )
        }

        await transport.shutdown()
    }
}

private actor RequestReplyCancellationGate {
    private var isBlocked = false
    private var releaseContinuation: CheckedContinuation<Void, Never>?
    private var arrivalContinuations: [CheckedContinuation<Void, Never>] = []

    func wait() async {
        isBlocked = true
        let arrivals = arrivalContinuations
        arrivalContinuations.removeAll(keepingCapacity: false)
        for continuation in arrivals {
            continuation.resume()
        }
        await withCheckedContinuation { continuation in
            releaseContinuation = continuation
        }
    }

    func waitUntilBlocked() async {
        guard !isBlocked else {
            return
        }
        await withCheckedContinuation { continuation in
            arrivalContinuations.append(continuation)
        }
    }

    func open() {
        let continuation = releaseContinuation
        releaseContinuation = nil
        continuation?.resume()
    }
}

private func requestReplyInvocation(callID: ActorCallID) -> ActorFrame {
    .invocation(
        ActorInvocationFrame(
            callID: callID,
            invocation: ActorInvocation(
                recipient: ActorAddress(
                    type: ActorTypeID(high: 7, low: 8),
                    identity: "request-reply-fixture"
                ),
                method: ActorMethodID(9),
                schemaFingerprint: ActorSchemaFingerprint(high: 10, low: 11),
                payload: ActorByteBuffer()
            ),
            remainingTimeoutNanoseconds: nil
        )
    )
}
