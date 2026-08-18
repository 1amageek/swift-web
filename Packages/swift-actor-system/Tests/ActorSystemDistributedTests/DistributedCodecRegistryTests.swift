import ActorSystemCore
@testable import ActorSystemDistributed
import ActorSystemTestSupport
import Distributed
import Synchronization
import Testing

@Suite
struct DistributedCodecRegistryTests {
    private struct UnregisteredDistributedError: Error {
        let reason: String
    }

    @Test
    func coreFailuresUseTheDistributedSystemErrorMarker() {
        let failure: any DistributedActorSystemError = ActorSystemError.cancelled
        #expect((failure as? ActorSystemError) == .cancelled)
    }

    @Test
    func registeredCodableValueUsesPortableBinaryCodec() throws {
        let registry = ActorDistributedCodecRegistry()
        try registry.register(
            Int.self,
            typeID: ActorTypeID(high: 1, low: 2),
            codec: .portable()
        )
        let encoder = ActorBinaryEncoder(registry: registry)
        let decoder = ActorBinaryDecoder(registry: registry)

        let payload = try encoder.encode(42)

        #expect(try decoder.decode(Int.self, from: payload) == 42)
    }

    @Test
    func unregisteredCodableValueFailsExplicitly() throws {
        let registry = ActorDistributedCodecRegistry()

        #expect(throws: ActorSystemError.self) {
            _ = try registry.encode(42)
        }
    }

    @Test
    func unregisteredThrownErrorBecomesRemoteFailure() async throws {
        let store = ActorDistributedResultStore()
        let handler = ActorDistributedResultHandler(
            registry: ActorDistributedCodecRegistry(),
            store: store
        )

        try await handler.onThrow(
            error: UnregisteredDistributedError(reason: "not portable")
        )

        guard case .systemFailure(let failure) = await store.take() else {
            Issue.record("Expected an unregistered error to become a system failure")
            return
        }
        #expect(failure.code == .remoteFailure)
    }

    @Test
    func aliasTableRequiresOneToOneCompilerMapping() throws {
        #expect(throws: ActorSystemError.self) {
            _ = try ActorTargetAliasTable(
                toolchainFingerprint: "fixture",
                aliases: [
                    "first": ActorMethodID(1),
                    "second": ActorMethodID(1),
                ]
            )
        }
    }

    @Test
    func identicalCodecRegistrationIsIdempotent() throws {
        let registry = ActorDistributedCodecRegistry()
        let typeID = ActorTypeID(high: 5, low: 6)
        try registry.register(Int.self, typeID: typeID, codec: .portable())
        try registry.register(Int.self, typeID: typeID, codec: .portable())

        #expect(try registry.decode(Int.self, from: registry.encode(7)) == 7)
    }

    @Test
    func conflictingCodecRegistrationFailsInsteadOfReplacingTheCodec() throws {
        let registry = ActorDistributedCodecRegistry()
        try registry.register(
            Int.self,
            typeID: ActorTypeID(high: 5, low: 6),
            codec: .portable()
        )
        #expect(throws: ActorSystemError.self) {
            try registry.register(
                Int.self,
                typeID: ActorTypeID(high: 5, low: 7),
                codec: .portable()
            )
        }
    }

    @Test
    func codecRegistrySnapshotDoesNotObserveLaterExternalMutation() throws {
        let registry = ActorDistributedCodecRegistry()
        let snapshot = registry.snapshot()
        try registry.register(
            Int.self,
            typeID: ActorTypeID(high: 6, low: 7),
            codec: .portable()
        )

        #expect(throws: ActorSystemError.self) {
            _ = try snapshot.encode(1)
        }
        #expect(try registry.decode(Int.self, from: registry.encode(1)) == 1)
    }

    @Test
    func registrationAfterShutdownFailsExplicitly() async throws {
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(30)
                )
            )
        )
        try await system.shutdown()

        #expect(throws: ActorSystemError.self) {
            try system.registerCodec(
                Int.self,
                typeID: ActorTypeID(high: 30, low: 31),
                codec: .portable()
            )
        }
    }

    @Test
    func identicalActorTypeRegistrationIsIdempotent() throws {
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(3)
                )
            )
        )
        let descriptor = ActorTypeDescriptor(
            id: ActorTypeID(high: 11, low: 1),
            schemaFingerprint: ActorSchemaFingerprint(high: 11, low: 2),
            methods: [
                ActorMethodDescriptor(
                    id: ActorMethodID(1),
                    parameterTypeIDs: [],
                    resultTypeID: nil,
                    errorTypeID: nil
                ),
            ]
        )
        let aliases = try ActorTargetAliasTable(
            toolchainFingerprint: "fixture",
            aliases: ["$s-fixture": ActorMethodID(1)]
        )
        let registration = DistributedActorTypeRegistration(
            RegistryFixtureActor.self,
            descriptor: descriptor,
            aliases: aliases
        ).eraseToAnyRegistration()

        try system.register(registration)
        try system.register(registration)
    }

    @Test
    func actorRegistrationsRejectMixedToolchainFingerprints() throws {
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(31)
                )
            )
        )
        let method = ActorMethodDescriptor(
            id: ActorMethodID(1),
            parameterTypeIDs: [],
            resultTypeID: nil,
            errorTypeID: nil
        )
        let first = DistributedActorTypeRegistration(
            RegistryFixtureActor.self,
            descriptor: ActorTypeDescriptor(
                id: ActorTypeID(high: 31, low: 1),
                schemaFingerprint: ActorSchemaFingerprint(high: 31, low: 2),
                methods: [method]
            ),
            aliases: try ActorTargetAliasTable(
                toolchainFingerprint: "first-toolchain",
                aliases: ["$s-first": method.id]
            )
        ).eraseToAnyRegistration()
        let second = DistributedActorTypeRegistration(
            SecondRegistryFixtureActor.self,
            descriptor: ActorTypeDescriptor(
                id: ActorTypeID(high: 31, low: 3),
                schemaFingerprint: ActorSchemaFingerprint(high: 31, low: 4),
                methods: [method]
            ),
            aliases: try ActorTargetAliasTable(
                toolchainFingerprint: "second-toolchain",
                aliases: ["$s-second": method.id]
            )
        ).eraseToAnyRegistration()

        try system.register(first)
        #expect(throws: ActorSystemError.self) {
            try system.register(second)
        }
    }

    @Test
    func generatedBootstrapInstallsBeforeIdentityAssignment() async throws {
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(4)
                )
            )
        )

        let first = RegistryFixtureActor(actorSystem: system)
        #expect(first.id.type == RegistryFixtureBootstrap.actorTypeID)

        try await system.start()
        let second = RegistryFixtureActor(actorSystem: system)
        #expect(second.id.type == RegistryFixtureBootstrap.actorTypeID)
        try await system.shutdown()
    }

    @Test
    func generatedBootstrapInstallsBeforeRemoteResolution() throws {
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(5)
                )
            )
        )
        let address = ActorAddress(
            type: RegistryFixtureBootstrap.actorTypeID,
            identity: "remote-registry-fixture"
        )

        let remote = try RegistryFixtureActor.resolve(id: address, using: system)

        #expect(remote.id == address)
    }

    @Test
    func applicationFailureMustMatchTheDeclaredErrorType() throws {
        let registry = ActorDistributedCodecRegistry()
        let typeID = ActorTypeID(high: 8, low: 9)
        try registry.register(
            FirstFixtureFailure.self,
            typeID: typeID,
            codec: ActorGeneratedCodec(
                encode: { _ in ActorByteBuffer([1]) },
                decode: { _ in FirstFixtureFailure.failed }
            )
        )
        let failure = ActorApplicationFailure(
            typeID: typeID,
            payload: ActorByteBuffer([1])
        )

        #expect(throws: ActorSystemError.self) {
            _ = try registry.decodeError(
                SecondFixtureFailure.self,
                from: failure
            )
        }
    }

    @Test
    func compositeBootstrapRegistersDiamondDependenciesOnceInDependencyOrder() async throws {
        BootstrapRegistrationLog.reset()
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(1)
                )
            )
        )

        try system.registerBootstrap(RootBootstrap.self)
        try system.registerBootstrap(SharedBootstrap.self)
        try await system.start()
        try system.registerBootstrap(RootBootstrap.self)

        #expect(
            BootstrapRegistrationLog.values == [
                "shared", "feature-a", "feature-b", "root",
            ]
        )
        try await system.shutdown()
    }

    @Test
    func failedBootstrapRestoresRegistriesAndCanBeRetried() throws {
        RetryableBootstrapState.reset()
        let registry = ActorDistributedCodecRegistry()
        let system = SwiftActorSystem(
            codecRegistry: registry,
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(2)
                )
            )
        )

        #expect(throws: ActorSystemError.self) {
            try system.registerBootstrap(RetryableBootstrap.self)
        }
        #expect(throws: ActorSystemError.self) {
            _ = try registry.encode(Int64(1))
        }

        RetryableBootstrapState.allowSuccess()
        try system.registerBootstrap(RetryableBootstrap.self)

        #expect(throws: ActorSystemError.self) {
            _ = try registry.encode(Int64(2))
        }
    }

    @Test
    func bootstrapDescriptorMismatchRollsBackActorRegistrations() throws {
        DescriptorMismatchBootstrapState.reset()
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(32)
                )
            )
        )

        do {
            try system.registerBootstrap(DescriptorMismatchBootstrap.self)
            Issue.record("Expected the bootstrap descriptor mismatch to fail")
        } catch ActorSystemError.invalidFrame(let violation) {
            #expect(
                violation.reason.contains(
                    "declared actor descriptors do not match its actor registrations"
                )
            )
        } catch {
            Issue.record("Unexpected bootstrap validation error: \(error)")
        }

        DescriptorMismatchBootstrapState.useDeclaredDescriptor()
        try system.registerBootstrap(DescriptorMismatchBootstrap.self)
    }

    @Test
    func bootstrapMissingMethodCodecRollsBackCodecsAndActorRegistrations() throws {
        MissingCodecBootstrapState.reset()
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(33)
                )
            )
        )

        do {
            try system.registerBootstrap(MissingCodecBootstrap.self)
            Issue.record("Expected the bootstrap with a missing method codec to fail")
        } catch ActorSystemError.invalidFrame(let violation) {
            #expect(violation.reason.contains("is missing codecs for method value type IDs"))
            #expect(violation.reason.contains("33:3"))
        } catch {
            Issue.record("Unexpected bootstrap validation error: \(error)")
        }

        MissingCodecBootstrapState.useDeclaredErrorTypeID()
        try system.registerBootstrap(MissingCodecBootstrap.self)
    }

    @Test
    func actorTypeCannotBeOwnedByMultipleBootstraps() throws {
        let system = SwiftActorSystem(
            configuration: ActorSystemConfiguration(
                sessionIdentitySource: FixedActorSessionIdentitySource(
                    ActorSessionID(34)
                )
            )
        )

        do {
            try system.registerBootstrap(DuplicateOwnerRootBootstrap.self)
            Issue.record("Expected duplicate bootstrap ownership to fail")
        } catch ActorSystemError.invalidFrame(let violation) {
            #expect(violation.reason.contains("is owned by more than one bootstrap"))
        } catch {
            Issue.record("Unexpected bootstrap ownership error: \(error)")
        }

        try system.registerBootstrap(FirstOwnerBootstrap.self)
    }
}

private enum FirstFixtureFailure: Error, Codable, Sendable {
    case failed
}

private enum SecondFixtureFailure: Error, Codable, Sendable {
    case failed
}

private distributed actor RegistryFixtureActor {
    typealias ActorSystem = SwiftActorSystem

    distributed func ping() async throws {}
}

private distributed actor SecondRegistryFixtureActor {
    typealias ActorSystem = SwiftActorSystem

    distributed func ping() async throws {}
}

private distributed actor DescriptorMismatchFixtureActor {
    typealias ActorSystem = SwiftActorSystem
}

private distributed actor MissingCodecFixtureActor {
    typealias ActorSystem = SwiftActorSystem
}

private distributed actor BootstrapOwnershipFixtureActor {
    typealias ActorSystem = SwiftActorSystem
}

private enum MissingCodecFixtureFailure: Error, Codable, ActorPortableValue {
    case failed

    func encodeActorValue() throws -> ActorByteBuffer {
        ActorByteBuffer()
    }

    static func decodeActorValue(
        from payload: ActorByteBuffer,
        options: ActorPortableDecodingOptions
    ) throws -> MissingCodecFixtureFailure {
        _ = options
        guard payload.count == 0 else {
            throw ActorSystemError.decodingFailed
        }
        return .failed
    }
}

extension RegistryFixtureActor: SwiftActorSystemBootstrapProvider {
    nonisolated static var actorSystemBootstrap: any SwiftActorSystemBootstrap.Type {
        RegistryFixtureBootstrap.self
    }
}

private enum RegistryFixtureBootstrap: SwiftActorSystemBootstrap {
    static let actorTypeID = ActorTypeID(high: 12, low: 1)
    static let methodID = ActorMethodID(1)
    static let descriptor = ActorTypeDescriptor(
        id: actorTypeID,
        schemaFingerprint: ActorSchemaFingerprint(high: 12, low: 2),
        methods: [
            ActorMethodDescriptor(
                id: methodID,
                parameterTypeIDs: [],
                resultTypeID: nil,
                errorTypeID: nil
            ),
        ]
    )
    static let bootstrapIdentifier = "registry-fixture"
    static let actorTypeDescriptors = [descriptor]

    static func register(in actorSystem: SwiftActorSystem) throws {
        let aliases = try ActorTargetAliasTable(
            toolchainFingerprint: "fixture",
            aliases: ["$s-registry-fixture": methodID]
        )
        try actorSystem.register(
            DistributedActorTypeRegistration(
                RegistryFixtureActor.self,
                descriptor: descriptor,
                aliases: aliases
            ).eraseToAnyRegistration()
        )
    }
}

private enum BootstrapRegistrationLog {
    private static let storage = Mutex<[String]>([])

    static var values: [String] {
        storage.withLock { $0 }
    }

    static func append(_ value: String) {
        storage.withLock { $0.append(value) }
    }

    static func reset() {
        storage.withLock { $0.removeAll(keepingCapacity: false) }
    }
}

private enum SharedBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "shared"
    static let actorTypeDescriptors: [ActorTypeDescriptor] = []

    static func register(in actorSystem: SwiftActorSystem) throws {
        BootstrapRegistrationLog.append("shared")
        try actorSystem.registerCodec(
            Int.self,
            typeID: ActorTypeID(high: 10, low: 1),
            codec: .portable()
        )
    }
}

private enum FeatureABootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "feature-a"
    static let dependencies: [any SwiftActorSystemBootstrap.Type] = [
        SharedBootstrap.self,
    ]
    static let actorTypeDescriptors: [ActorTypeDescriptor] = []

    static func register(in actorSystem: SwiftActorSystem) throws {
        BootstrapRegistrationLog.append("feature-a")
        try actorSystem.registerCodec(
            String.self,
            typeID: ActorTypeID(high: 10, low: 2),
            codec: .portable()
        )
    }
}

private enum FeatureBBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "feature-b"
    static let dependencies: [any SwiftActorSystemBootstrap.Type] = [
        SharedBootstrap.self,
    ]
    static let actorTypeDescriptors: [ActorTypeDescriptor] = []

    static func register(in actorSystem: SwiftActorSystem) throws {
        BootstrapRegistrationLog.append("feature-b")
        try actorSystem.registerCodec(
            UInt.self,
            typeID: ActorTypeID(high: 10, low: 3),
            codec: .portable()
        )
    }
}

private enum RootBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "root"
    static let dependencies: [any SwiftActorSystemBootstrap.Type] = [
        FeatureBBootstrap.self,
        FeatureABootstrap.self,
    ]
    static let actorTypeDescriptors: [ActorTypeDescriptor] = []

    static func register(in actorSystem: SwiftActorSystem) throws {
        BootstrapRegistrationLog.append("root")
        try actorSystem.registerCodec(
            Bool.self,
            typeID: ActorTypeID(high: 10, low: 4),
            codec: .portable()
        )
    }
}

private enum RetryableBootstrapState {
    private static let shouldFail = Mutex(true)

    static func reset() {
        shouldFail.withLock { $0 = true }
    }

    static func allowSuccess() {
        shouldFail.withLock { $0 = false }
    }

    static var failureIsEnabled: Bool {
        shouldFail.withLock { $0 }
    }
}

private enum RetryableBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "retryable"
    static let actorTypeDescriptors: [ActorTypeDescriptor] = []

    static func register(in actorSystem: SwiftActorSystem) throws {
        try actorSystem.registerCodec(
            Int64.self,
            typeID: ActorTypeID(high: 10, low: 5),
            codec: .portable()
        )
        if RetryableBootstrapState.failureIsEnabled {
            throw ActorSystemError.overloaded
        }
    }
}

private enum DescriptorMismatchBootstrapState {
    private static let usesDeclaredDescriptor = Mutex(false)

    static func reset() {
        usesDeclaredDescriptor.withLock { $0 = false }
    }

    static func useDeclaredDescriptor() {
        usesDeclaredDescriptor.withLock { $0 = true }
    }

    static var isUsingDeclaredDescriptor: Bool {
        usesDeclaredDescriptor.withLock { $0 }
    }
}

private enum DescriptorMismatchBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "descriptor-mismatch"
    static let descriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 32, low: 1),
        schemaFingerprint: ActorSchemaFingerprint(high: 32, low: 2),
        methods: []
    )
    static let mismatchedDescriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 32, low: 3),
        schemaFingerprint: ActorSchemaFingerprint(high: 32, low: 4),
        methods: []
    )
    static let actorTypeDescriptors = [descriptor]

    static func register(in actorSystem: SwiftActorSystem) throws {
        let selectedDescriptor = DescriptorMismatchBootstrapState.isUsingDeclaredDescriptor
            ? descriptor
            : mismatchedDescriptor
        try actorSystem.register(
            DistributedActorTypeRegistration(
                DescriptorMismatchFixtureActor.self,
                descriptor: selectedDescriptor,
                aliases: ActorTargetAliasTable(
                    toolchainFingerprint: "bootstrap-validation",
                    aliases: [:]
                )
            ).eraseToAnyRegistration()
        )
    }
}

private enum MissingCodecBootstrapState {
    private static let usesDeclaredErrorTypeID = Mutex(false)

    static func reset() {
        usesDeclaredErrorTypeID.withLock { $0 = false }
    }

    static func useDeclaredErrorTypeID() {
        usesDeclaredErrorTypeID.withLock { $0 = true }
    }

    static var isUsingDeclaredErrorTypeID: Bool {
        usesDeclaredErrorTypeID.withLock { $0 }
    }
}

private enum MissingCodecBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "missing-method-codec"
    static let parameterTypeID = ActorTypeID(high: 33, low: 1)
    static let resultTypeID = ActorTypeID(high: 33, low: 2)
    static let errorTypeID = ActorTypeID(high: 33, low: 3)
    static let unrelatedErrorTypeID = ActorTypeID(high: 33, low: 4)
    static let methodID = ActorMethodID(1)
    static let descriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 33, low: 5),
        schemaFingerprint: ActorSchemaFingerprint(high: 33, low: 6),
        methods: [
            ActorMethodDescriptor(
                id: methodID,
                parameterTypeIDs: [parameterTypeID],
                resultTypeID: resultTypeID,
                errorTypeID: errorTypeID
            ),
        ]
    )
    static let actorTypeDescriptors = [descriptor]

    static func register(in actorSystem: SwiftActorSystem) throws {
        try actorSystem.registerCodec(
            Int.self,
            typeID: parameterTypeID,
            codec: .portable()
        )
        try actorSystem.registerCodec(
            String.self,
            typeID: resultTypeID,
            codec: .portable()
        )
        try actorSystem.registerCodec(
            MissingCodecFixtureFailure.self,
            typeID: MissingCodecBootstrapState.isUsingDeclaredErrorTypeID
                ? errorTypeID
                : unrelatedErrorTypeID,
            codec: .portable()
        )
        try actorSystem.register(
            DistributedActorTypeRegistration(
                MissingCodecFixtureActor.self,
                descriptor: descriptor,
                aliases: ActorTargetAliasTable(
                    toolchainFingerprint: "bootstrap-validation",
                    aliases: ["$s-missing-codec": methodID]
                )
            ).eraseToAnyRegistration()
        )
    }
}

private enum BootstrapOwnershipFixture {
    static let descriptor = ActorTypeDescriptor(
        id: ActorTypeID(high: 34, low: 1),
        schemaFingerprint: ActorSchemaFingerprint(high: 34, low: 2),
        methods: []
    )

    static func register(in actorSystem: SwiftActorSystem) throws {
        try actorSystem.register(
            DistributedActorTypeRegistration(
                BootstrapOwnershipFixtureActor.self,
                descriptor: descriptor,
                aliases: ActorTargetAliasTable(
                    toolchainFingerprint: "bootstrap-validation",
                    aliases: [:]
                )
            ).eraseToAnyRegistration()
        )
    }
}

private enum FirstOwnerBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "first-owner"
    static let actorTypeDescriptors = [BootstrapOwnershipFixture.descriptor]

    static func register(in actorSystem: SwiftActorSystem) throws {
        try BootstrapOwnershipFixture.register(in: actorSystem)
    }
}

private enum SecondOwnerBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "second-owner"
    static let actorTypeDescriptors = [BootstrapOwnershipFixture.descriptor]

    static func register(in actorSystem: SwiftActorSystem) throws {
        try BootstrapOwnershipFixture.register(in: actorSystem)
    }
}

private enum DuplicateOwnerRootBootstrap: SwiftActorSystemBootstrap {
    static let bootstrapIdentifier = "duplicate-owner-root"
    static let actorTypeDescriptors: [ActorTypeDescriptor] = []
    static let dependencies: [any SwiftActorSystemBootstrap.Type] = [
        FirstOwnerBootstrap.self,
        SecondOwnerBootstrap.self,
    ]

    static func register(in actorSystem: SwiftActorSystem) throws {
        _ = actorSystem
    }
}
