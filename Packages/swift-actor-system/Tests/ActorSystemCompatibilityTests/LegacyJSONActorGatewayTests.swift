import ActorSystemCompatibility
import ActorSystemCore
#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import Testing

@Suite
struct LegacyJSONActorGatewayTests {
    @Test
    func explicitLegacyBridgeTranslatesJsonToPortableFrames() async throws {
        let method = ActorMethodID(3)
        let address = ActorAddress(
            type: ActorTypeID(high: 1, low: 2),
            identity: "main"
        )
        let fingerprint = ActorSchemaFingerprint(high: 4, low: 5)
        let bridge = try LegacyActorBridgeDescriptor(
            legacyContract: "Fixture.Counter",
            actorTypeID: address.type,
            schemaFingerprint: fingerprint,
            methods: [
                LegacyActorMethodBridge(
                    legacyTargetIdentifier: "increment",
                    methodID: method,
                    decodeArguments: { arguments in
                        guard arguments.count == 1 else {
                            throw ActorSystemError.decodingFailed
                        }
                        return try JSONDecoder().decode(Int.self, from: arguments[0])
                            .encodeActorValue()
                    },
                    encodeResult: { payload in
                        let value = try Int.decodeActorValue(
                            from: payload,
                            options: .init()
                        )
                        return try JSONEncoder().encode(value)
                    }
                ),
            ]
        )
        let gateway = try LegacyJSONActorGateway(
            sessionID: ActorSessionID(9),
            descriptors: [bridge]
        )
        let directory = ActorDirectory()
        try directory.register(
            LegacyIncrementTarget(
                address: address,
                method: method,
                fingerprint: fingerprint
            )
        )
        let core = ActorSystemCore(
            directory: directory,
            transports: [gateway.transportID: gateway],
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(10))
            )
        )
        try await core.start()

        let response = try await gateway.handle(
            InvocationEnvelope(
                callID: "legacy-call",
                recipientID: "Fixture.Counter:main",
                target: "increment",
                arguments: [try JSONEncoder().encode(41)]
            )
        )

        #expect(response.callID == "legacy-call")
        switch response.result {
        case .success(let data):
            #expect(try JSONDecoder().decode(Int.self, from: data) == 42)
        default:
            Issue.record("Expected a successful legacy response")
        }
        try await core.shutdown()
    }

    @Test
    func duplicateLegacyContractFailsAtGatewayConstruction() throws {
        let descriptor = try LegacyActorBridgeDescriptor(
            legacyContract: "Fixture.Counter",
            actorTypeID: ActorTypeID(high: 1, low: 2),
            schemaFingerprint: ActorSchemaFingerprint(high: 3, low: 4),
            methods: []
        )

        #expect(throws: ActorSystemError.self) {
            _ = try LegacyJSONActorGateway(
                sessionID: ActorSessionID(1),
                descriptors: [descriptor, descriptor]
            )
        }
    }

    @Test
    func invalidLegacyTransportBoundsFailAtConstruction() {
        #expect(throws: ActorSystemError.self) {
            _ = try LegacyJSONActorGateway(
                sessionID: ActorSessionID(0),
                descriptors: []
            )
        }
        #expect(throws: ActorSystemError.self) {
            _ = try LegacyJSONActorGateway(
                sessionID: ActorSessionID(1),
                descriptors: [],
                maximumPendingCalls: 0
            )
        }
    }

    @Test
    func oversizedLegacyEnvelopeFailsBeforeDescriptorLookup() async throws {
        let gateway = try LegacyJSONActorGateway(
            sessionID: ActorSessionID(2),
            descriptors: [],
            maximumPayloadBytes: 1
        )
        try await gateway.start()

        await #expect(throws: RuntimeError.self) {
            _ = try await gateway.handle(
                InvocationEnvelope(
                    callID: "bounded-call",
                    recipientID: "Fixture.Counter:main",
                    target: "increment",
                    arguments: [Data([0x01, 0x02])]
                )
            )
        }

        await gateway.shutdown()
    }
}

private struct LegacyIncrementTarget: ActorInvocationTarget {
    let address: ActorAddress
    let descriptor: ActorTypeDescriptor

    init(
        address: ActorAddress,
        method: ActorMethodID,
        fingerprint: ActorSchemaFingerprint
    ) {
        self.address = address
        self.descriptor = ActorTypeDescriptor(
            id: address.type,
            schemaFingerprint: fingerprint,
            methods: [
                ActorMethodDescriptor(
                    id: method,
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
    }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        let value = try Int.decodeActorValue(
            from: invocation.payload,
            options: .init()
        )
        return ActorInvocationResult(payload: try (value + 1).encodeActorValue())
    }
}
