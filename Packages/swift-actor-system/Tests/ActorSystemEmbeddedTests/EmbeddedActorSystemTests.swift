import ActorSystemCore
import ActorSystemEmbedded
import ActorSystemTestSupport
import Synchronization
import Testing

@Suite
struct EmbeddedActorSystemTests {
    @Test
    func resolveRejectsAnAddressForAnotherActorType() throws {
        let system = EmbeddedActorSystem(
            configuration: embeddedConfiguration(session: 39)
        )
        let address = ActorAddress(
            type: ActorTypeID(high: 1, low: 2),
            identity: "wrong-type"
        )

        do {
            let _: EmbeddedWrongTypeResolutionProbe = try system.resolve(
                id: address,
                as: EmbeddedWrongTypeResolutionProbe.self,
                makeRemote: { EmbeddedWrongTypeResolutionProbe() }
            )
            Issue.record("Expected actorNotFound")
        } catch let error as ActorSystemError {
            #expect(error == .actorNotFound(address))
        }
    }

    @Test
    func resolveAfterShutdownFailsExplicitly() async throws {
        let system = EmbeddedActorSystem(
            configuration: embeddedConfiguration(session: 40)
        )
        try await system.shutdown()
        let typeID = ActorTypeID(high: 5, low: 6)
        let address = ActorAddress(type: typeID, identity: "terminated")

        do {
            let _: EmbeddedTerminatedResolutionProbe = try system.resolve(
                id: address,
                as: EmbeddedTerminatedResolutionProbe.self,
                makeRemote: { EmbeddedTerminatedResolutionProbe() }
            )
            Issue.record("Expected shuttingDown")
        } catch let error as ActorSystemError {
            #expect(error == .shuttingDown)
        }
    }

    @Test
    func registrationAfterShutdownFailsExplicitly() async throws {
        let system = EmbeddedActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(40)
                )
            )
        )
        try await system.shutdown()
        let address = system.assignID(actorType: ActorTypeID(high: 40, low: 41))
        let target = EmbeddedFixtureTarget(
            address: address,
            method: ActorMethodID(44),
            fingerprint: ActorSchemaFingerprint(high: 42, low: 43),
            behavior: .increment
        )

        #expect(throws: ActorSystemError.self) {
            try system.register(EmbeddedRegistrationProbe(), target: target)
        }
    }

    @Test
    func generatedRuntimeSupportInvokesRemoteTarget() async throws {
        let fixture = try EmbeddedPairFixture(target: .increment)
        try await fixture.start()

        let result: Int = try await fixture.client.invoke(
            actor: fixture.address,
            method: fixture.method,
            schemaFingerprint: fixture.fingerprint,
            argument: 41,
            argumentCodec: .portable(),
            resultCodec: .portable()
        )

        #expect(result == 42)
        try await fixture.shutdown()
    }

    @Test
    func generatedRuntimeSupportDecodesTypedApplicationError() async throws {
        let fixture = try EmbeddedPairFixture(target: .reject)
        try await fixture.start()
        let errorTypeID = ActorTypeID(high: 20, low: 21)

        do {
            let _: Int = try await fixture.client.invoke(
                actor: fixture.address,
                method: fixture.method,
                schemaFingerprint: fixture.fingerprint,
                argument: 1,
                argumentCodec: .portable(),
                resultCodec: .portable(),
                errorCodec: EmbeddedActorErrorCodec(
                    typeID: errorTypeID,
                    codec: .portable(EmbeddedFixtureError.self)
                )
            )
            Issue.record("Expected a typed application error")
        } catch let error as EmbeddedFixtureError {
            #expect(error == .rejected(1))
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
        try await fixture.shutdown()
    }

    @Test
    func shutdownReleasesInstancesOutsideTheRegistrationLock() async throws {
        let system = EmbeddedActorSystem(
            configuration: embeddedConfiguration(session: 41)
        )
        let address = ActorAddress(
            type: ActorTypeID(high: 42, low: 43),
            identity: "release-reentry"
        )
        let didRelease = Mutex(false)
        var instance: EmbeddedReleaseProbe? = EmbeddedReleaseProbe {
            system.unregister(address: address)
            didRelease.withLock { $0 = true }
        }
        try system.register(
            #require(instance),
            target: EmbeddedFixtureTarget(
                address: address,
                method: ActorMethodID(44),
                fingerprint: ActorSchemaFingerprint(high: 45, low: 46),
                behavior: .increment
            )
        )
        instance = nil

        try await system.shutdown()

        #expect(didRelease.withLock { $0 })
    }
}

private final class EmbeddedReleaseProbe: Sendable {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 42, low: 43),
        schemaFingerprint: ActorSchemaFingerprint(high: 45, low: 46),
        methods: []
    )

    private let onDeinit: @Sendable () -> Void

    init(onDeinit: @escaping @Sendable () -> Void) {
        self.onDeinit = onDeinit
    }

    deinit {
        onDeinit()
    }
}

extension EmbeddedReleaseProbe: EmbeddedActorInstance {}

private final class EmbeddedWrongTypeResolutionProbe: EmbeddedActorInstance, Sendable {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 3, low: 4),
        schemaFingerprint: ActorSchemaFingerprint(high: 5, low: 6),
        methods: []
    )
}

private final class EmbeddedTerminatedResolutionProbe: EmbeddedActorInstance, Sendable {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 5, low: 6),
        schemaFingerprint: ActorSchemaFingerprint(high: 7, low: 8),
        methods: []
    )
}

private final class EmbeddedRegistrationProbe: EmbeddedActorInstance, Sendable {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 40, low: 41),
        schemaFingerprint: ActorSchemaFingerprint(high: 42, low: 43),
        methods: []
    )
}

private final class EmbeddedPairInstance: EmbeddedActorInstance, Sendable {
    static let actorTypeDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 1, low: 2),
        schemaFingerprint: ActorSchemaFingerprint(high: 4, low: 5),
        methods: []
    )
}

private struct EmbeddedPairFixture: Sendable {
    enum Behavior: Sendable {
        case increment
        case reject
    }

    let client: EmbeddedActorSystem
    let server: EmbeddedActorSystem
    let address = ActorAddress(
        type: ActorTypeID(high: 1, low: 2),
        identity: "embedded"
    )
    let method = ActorMethodID(3)
    let fingerprint = ActorSchemaFingerprint(high: 4, low: 5)

    init(target behavior: Behavior) throws {
        let clientTransportID = ActorTransportID("embedded-client")
        let serverTransportID = ActorTransportID("embedded-server")
        let clientTransport = LoopbackActorTransport(
            transportID: clientTransportID,
            endpoint: ActorEndpoint("embedded-client")
        )
        let serverTransport = LoopbackActorTransport(
            transportID: serverTransportID,
            endpoint: ActorEndpoint("embedded-server")
        )
        try clientTransport.connect(to: serverTransport)
        try serverTransport.connect(to: clientTransport)
        self.client = EmbeddedActorSystem(
            router: StaticActorRouter(
                routes: [
                    address.type: ActorRoute(
                        transport: clientTransportID,
                        endpoint: serverTransport.endpoint
                    ),
                ]
            ),
            transports: [clientTransportID: clientTransport],
            configuration: embeddedConfiguration(session: 1)
        )
        self.server = EmbeddedActorSystem(
            transports: [serverTransportID: serverTransport],
            configuration: embeddedConfiguration(session: 2)
        )
        try server.register(
            EmbeddedPairInstance(),
            target: EmbeddedFixtureTarget(
                address: address,
                method: method,
                fingerprint: fingerprint,
                behavior: behavior
            )
        )
    }

    func start() async throws {
        try await server.start()
        try await client.start()
    }

    func shutdown() async throws {
        try await client.shutdown()
        try await server.shutdown()
    }
}

private struct EmbeddedFixtureTarget: ActorInvocationTarget {
    let address: ActorAddress
    let descriptor: ActorTypeDescriptor
    let behavior: EmbeddedPairFixture.Behavior

    init(
        address: ActorAddress,
        method: ActorMethodID,
        fingerprint: ActorSchemaFingerprint,
        behavior: EmbeddedPairFixture.Behavior
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
        self.behavior = behavior
    }

    func invoke(
        _ invocation: ActorInvocation,
        context: ActorInvocationContext
    ) async throws -> ActorInvocationResult {
        let value = try Int.decodeActorValue(
            from: invocation.payload,
            options: .init()
        )
        switch behavior {
        case .increment:
            return ActorInvocationResult(payload: try (value + 1).encodeActorValue())
        case .reject:
            throw ActorApplicationFailure(
                typeID: ActorTypeID(high: 20, low: 21),
                payload: try EmbeddedFixtureError.rejected(value).encodeActorValue()
            )
        }
    }
}

private enum EmbeddedFixtureError: Error, Equatable, Sendable, ActorPortableValue {
    case rejected(Int)

    func encodeActorValue() throws -> ActorByteBuffer {
        switch self {
        case .rejected(let value):
            var associated = ActorPayloadEncoder()
            try associated.append(
                message: value.encodeActorValue(),
                field: ActorFieldID(1)
            )
            var payload = ActorPayloadEncoder()
            try payload.appendEnumeration(
                caseID: 1,
                associatedValues: associated.finish(),
                field: ActorFieldID(1)
            )
            return payload.finish()
        }
    }

    static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> EmbeddedFixtureError {
        var decoder = try ActorPayloadDecoder(
            payload,
            maximumCollectionElements: options.maximumCollectionElements,
            maximumNestingDepth: options.maximumNestingDepth
        )
        guard let field = try decoder.nextField(),
              field.id == ActorFieldID(1),
              field.wireType == .enumeration,
              try decoder.nextField() == nil
        else {
            throw ActorSystemError.decodingFailed
        }
        var enumeration = try field.decodeEnumeration()
        guard enumeration.caseID == 1,
              let valueField = try enumeration.associatedValues.nextField(),
              valueField.id == ActorFieldID(1),
              valueField.wireType == .message,
              try enumeration.associatedValues.nextField() == nil
        else {
            throw ActorSystemError.decodingFailed
        }
        return .rejected(
            try Int.decodeActorValue(
                from: valueField.payloadBuffer(),
                options: options
            )
        )
    }
}

private func embeddedConfiguration(session: UInt64) -> ActorSystemConfiguration {
    ActorSystemConfiguration(
        sessionIdentitySource: FixedActorSessionIdentitySource(ActorSessionID(session))
    )
}
