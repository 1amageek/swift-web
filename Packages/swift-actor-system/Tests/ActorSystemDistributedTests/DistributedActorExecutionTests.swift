import ActorSystemCore
import ActorSystemDistributed
import ActorSystemTestSupport
import Distributed
import Synchronization
import Testing

@Suite
struct DistributedActorExecutionTests {
    @Test
    func compilerThunkExecutesARealRemoteDistributedActor() async throws {
        let compilerTarget = try await Self.captureIncrementTarget()
        let fixture = try DistributedCounterFixture(compilerTarget: compilerTarget)
        try await fixture.start()

        let remote = try DistributedCounter.resolve(
            id: fixture.serverCounter.id,
            using: fixture.clientSystem
        )
        let result = try await remote.increment(by: 41)

        #expect(result == 42)
        #expect(try await fixture.serverCounter.observedInvocationCount() == 1)
        try await fixture.shutdown()
    }

    @Test
    func registrationRejectsAliasesThatDoNotMatchDescriptorMethods() throws {
        let backend = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(203)
                )
            )
        )
        let aliases = try ActorTargetAliasTable(
            toolchainFingerprint: "registration-validation-toolchain",
            aliases: ["unexpected-target": ActorMethodID(999)]
        )
        let descriptor = ActorTypeDescriptor(
            id: DistributedCounterFixture.actorTypeID,
            schemaFingerprint: DistributedCounterFixture.fingerprint,
            methods: [
                ActorMethodDescriptor(
                    id: DistributedCounterFixture.methodID,
                    parameterTypeIDs: [DistributedCounterFixture.integerTypeID],
                    resultTypeID: DistributedCounterFixture.integerTypeID,
                    errorTypeID: nil
                ),
            ]
        )

        #expect(throws: ActorSystemError.self) {
            try backend.register(
                DistributedActorTypeRegistration(
                    DistributedCounter.self,
                    descriptor: descriptor,
                    aliases: aliases
                ).eraseToAnyRegistration()
            )
        }
    }

    private static func captureIncrementTarget() async throws -> String {
        let capturedTarget = TargetCapture()
        let system = try TestDistributedActorSystem(capturingTargetIn: capturedTarget)
        let remote = try DistributedCounter.resolve(
            id: ActorAddress(
                type: DistributedCounterFixture.actorTypeID,
                identity: "compiler-target-probe"
            ),
            using: system
        )
        do {
            _ = try await remote.increment(by: 0)
            Issue.record("Expected the target capture system to stop the call")
        } catch TestDistributedActorSystem.CaptureError.targetCaptured {
            #expect(capturedTarget.value != nil)
        } catch {
            Issue.record("Unexpected compiler target capture error: \(error)")
        }
        return try #require(capturedTarget.value)
    }
}

private distributed actor DistributedCounter {
    typealias ActorSystem = TestDistributedActorSystem

    private var value = 1
    private(set) var invocationCount = 0

    distributed func increment(by amount: Int) async throws -> Int {
        invocationCount += 1
        value += amount
        return value
    }

    distributed func observedInvocationCount() async throws -> Int {
        invocationCount
    }
}

private struct DistributedCounterFixture: Sendable {
    static let actorTypeID = ActorTypeID(high: 100, low: 101)
    static let integerTypeID = ActorTypeID(high: 102, low: 103)
    static let methodID = ActorMethodID(104)
    static let fingerprint = ActorSchemaFingerprint(high: 105, low: 106)

    let clientBackend: SwiftActorSystem
    let serverBackend: SwiftActorSystem
    let clientSystem: TestDistributedActorSystem
    let serverCounter: DistributedCounter

    init(compilerTarget: String) throws {
        let clientTransportID = ActorTransportID("distributed-client")
        let serverTransportID = ActorTransportID("distributed-server")
        let clientTransport = LoopbackActorTransport(
            transportID: clientTransportID,
            endpoint: ActorEndpoint("distributed-client")
        )
        let serverTransport = LoopbackActorTransport(
            transportID: serverTransportID,
            endpoint: ActorEndpoint("distributed-server")
        )
        try clientTransport.connect(to: serverTransport)
        try serverTransport.connect(to: clientTransport)

        let clientBackend = SwiftActorSystem(
            router: StaticActorRouter(routes: [
                Self.actorTypeID: ActorRoute(
                    transport: clientTransportID,
                    endpoint: serverTransport.endpoint
                ),
            ]),
            transports: [clientTransportID: clientTransport],
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(201)
                )
            )
        )
        let serverBackend = SwiftActorSystem(
            transports: [serverTransportID: serverTransport],
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(202)
                )
            )
        )
        let aliases = try ActorTargetAliasTable(
            toolchainFingerprint: "captured-test-toolchain",
            aliases: [compilerTarget: Self.methodID]
        )
        let descriptor = ActorTypeDescriptor(
            id: Self.actorTypeID,
            schemaFingerprint: Self.fingerprint,
            methods: [
                ActorMethodDescriptor(
                    id: Self.methodID,
                    parameterTypeIDs: [Self.integerTypeID],
                    resultTypeID: Self.integerTypeID,
                    errorTypeID: nil
                ),
            ]
        )
        for backend in [clientBackend, serverBackend] {
            try backend.registerCodec(
                Int.self,
                typeID: Self.integerTypeID,
                codec: .portable()
            )
            try backend.register(
                DistributedActorTypeRegistration(
                    DistributedCounter.self,
                    descriptor: descriptor,
                    aliases: aliases
                ).eraseToAnyRegistration()
            )
        }

        let clientSystem = TestDistributedActorSystem(backend: clientBackend)
        let serverSystem = TestDistributedActorSystem(backend: serverBackend)
        self.clientBackend = clientBackend
        self.serverBackend = serverBackend
        self.clientSystem = clientSystem
        self.serverCounter = DistributedCounter(actorSystem: serverSystem)
    }

    func start() async throws {
        try await serverBackend.start()
        try await clientBackend.start()
    }

    func shutdown() async throws {
        try await clientBackend.shutdown()
        try await serverBackend.shutdown()
    }
}

private final class TargetCapture: Sendable {
    private let storage = Mutex<String?>(nil)

    var value: String? {
        storage.withLock { $0 }
    }

    func store(_ value: String) {
        storage.withLock { $0 = value }
    }
}

private final class TestDistributedActorSystem: DistributedActorSystem, Sendable {
    enum CaptureError: Error {
        case targetCaptured
    }

    typealias ActorID = ActorAddress
    typealias InvocationEncoder = ActorDistributedInvocationEncoder
    typealias InvocationDecoder = ActorDistributedInvocationDecoder
    typealias ResultHandler = ActorDistributedResultHandler
    typealias SerializationRequirement = Codable & Sendable

    private let backend: SwiftActorSystem?
    private let captureRegistry: ActorDistributedCodecRegistry?
    private let capturedTarget: TargetCapture?

    init(backend: SwiftActorSystem) {
        self.backend = backend
        self.captureRegistry = nil
        self.capturedTarget = nil
    }

    init(capturingTargetIn capturedTarget: TargetCapture) throws {
        let registry = ActorDistributedCodecRegistry()
        try registry.register(
            Int.self,
            typeID: DistributedCounterFixture.integerTypeID,
            codec: .portable()
        )
        self.backend = nil
        self.captureRegistry = registry
        self.capturedTarget = capturedTarget
    }

    func resolve<Act>(
        id: ActorAddress,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorAddress {
        guard let backend else {
            return nil
        }
        return try backend.resolve(id: id, as: actorType)
    }

    func assignID<Act>(_ actorType: Act.Type) -> ActorAddress
    where Act: DistributedActor, Act.ID == ActorAddress {
        guard let backend else {
            preconditionFailure("The compiler target capture system cannot host actors")
        }
        return backend.assignID(actorType)
    }

    func actorReady<Act>(_ actor: Act)
    where Act: DistributedActor, Act.ID == ActorAddress {
        guard let backend else {
            preconditionFailure("The compiler target capture system cannot host actors")
        }
        backend.actorReady(actor)
    }

    func resignID(_ id: ActorAddress) {
        guard let backend else {
            preconditionFailure("The compiler target capture system cannot host actors")
        }
        backend.resignID(id)
    }

    func makeInvocationEncoder() -> ActorDistributedInvocationEncoder {
        if let backend {
            return backend.makeInvocationEncoder()
        }
        guard let captureRegistry else {
            preconditionFailure("The compiler target capture registry is unavailable")
        }
        return ActorDistributedInvocationEncoder(registry: captureRegistry)
    }

    func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout ActorDistributedInvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorAddress,
          Err: Error,
          Res: Codable & Sendable {
        if let capturedTarget {
            capturedTarget.store(target.identifier)
            throw CaptureError.targetCaptured
        }
        guard let backend else {
            throw ActorSystemError.notStarted
        }
        return try await backend.remoteCall(
            on: actor,
            target: target,
            invocation: &invocation,
            throwing: throwing,
            returning: returning
        )
    }

    func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout ActorDistributedInvocationEncoder,
        throwing: Err.Type
    ) async throws
    where Act: DistributedActor, Act.ID == ActorAddress, Err: Error {
        if let capturedTarget {
            capturedTarget.store(target.identifier)
            throw CaptureError.targetCaptured
        }
        guard let backend else {
            throw ActorSystemError.notStarted
        }
        try await backend.remoteCallVoid(
            on: actor,
            target: target,
            invocation: &invocation,
            throwing: throwing
        )
    }
}

private final class CapturingDistributedActorSystem: DistributedActorSystem, Sendable {
    enum CaptureError: Error {
        case targetCaptured
    }

    typealias ActorID = ActorAddress
    typealias InvocationEncoder = ActorDistributedInvocationEncoder
    typealias InvocationDecoder = ActorDistributedInvocationDecoder
    typealias ResultHandler = ActorDistributedResultHandler
    typealias SerializationRequirement = Codable & Sendable

    private let registry = ActorDistributedCodecRegistry()
    private let target = Mutex<String?>(nil)

    init() throws {
        try registry.register(
            Int.self,
            typeID: DistributedCounterFixture.integerTypeID,
            codec: .portable()
        )
    }

    var capturedTarget: String? {
        target.withLock { $0 }
    }

    func resolve<Act>(
        id: ActorAddress,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorAddress {
        nil
    }

    func assignID<Act>(_ actorType: Act.Type) -> ActorAddress
    where Act: DistributedActor, Act.ID == ActorAddress {
        preconditionFailure("The compiler target capture system cannot host actors")
    }

    func actorReady<Act>(_ actor: Act)
    where Act: DistributedActor, Act.ID == ActorAddress {
        preconditionFailure("The compiler target capture system cannot host actors")
    }

    func resignID(_ id: ActorAddress) {
        preconditionFailure("The compiler target capture system cannot host actors")
    }

    func makeInvocationEncoder() -> ActorDistributedInvocationEncoder {
        ActorDistributedInvocationEncoder(registry: registry)
    }

    func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout ActorDistributedInvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorAddress,
          Err: Error,
          Res: Codable & Sendable {
        self.target.withLock { $0 = target.identifier }
        throw CaptureError.targetCaptured
    }

    func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout ActorDistributedInvocationEncoder,
        throwing: Err.Type
    ) async throws
    where Act: DistributedActor, Act.ID == ActorAddress, Err: Error {
        self.target.withLock { $0 = target.identifier }
        throw CaptureError.targetCaptured
    }
}
