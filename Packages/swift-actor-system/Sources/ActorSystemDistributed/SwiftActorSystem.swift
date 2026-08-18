@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
import Distributed
import Synchronization

public final class SwiftActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = ActorAddress
    public typealias InvocationEncoder = ActorDistributedInvocationEncoder
    public typealias InvocationDecoder = ActorDistributedInvocationDecoder
    public typealias ResultHandler = ActorDistributedResultHandler
    public typealias SerializationRequirement = Codable & Sendable

    private let directory: ActorDirectory
    private let core: ActorSystemCore
    private let lifecycle: ActorSystemLifecycleCoordinator
    private let configuration: ActorSystemConfiguration
    private let codecs: ActorDistributedCodecRegistry
    private let actorTypes = ActorDistributedTypeRegistry()
    private let localActors = LocalDistributedActorStore()
    private let localRegistrations = Mutex(false)
    private let bootstrapRegistration = Mutex(false)
    private let actorIdentitySource: any ActorIdentitySource
    private let callOptions: ActorCallOptions
    private struct RegistrationState: Sendable {
        var isSealed = false
        var isTerminated = false
        var transactionInProgress = false
        var installedBootstraps: Set<ObjectIdentifier> = []
        var installedBootstrapIdentifiers: [String: ObjectIdentifier] = [:]
        var bootstrapOwnerByActorTypeID: [ActorTypeID: ObjectIdentifier] = [:]
    }
    private struct BootstrapRegistrationCheckpoint: Sendable {
        let bootstraps: Set<ObjectIdentifier>
        let identifiers: [String: ObjectIdentifier]
        let actorOwners: [ActorTypeID: ObjectIdentifier]
    }
    private let registrationState = Mutex(RegistrationState())
    @TaskLocal private static var isRegisteringBootstrap = false
    @TaskLocal private static var bootstrapRegistrationAudit: BootstrapRegistrationAudit?

    /// A supplied codec registry is snapshotted so later external mutations
    /// cannot change this system's wire contract.
    public init(
        codecRegistry: ActorDistributedCodecRegistry = ActorDistributedCodecRegistry(),
        actorIdentitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) {
        let directory = ActorDirectory()
        self.directory = directory
        self.configuration = configuration
        self.codecs = codecRegistry.snapshot()
        self.actorIdentitySource = actorIdentitySource
        self.callOptions = callOptions
        let core = ActorSystemCore(
            directory: directory,
            router: router,
            transports: transports,
            configuration: configuration
        )
        self.core = core
        self.lifecycle = ActorSystemLifecycleCoordinator(
            start: {
                try await core.start()
            },
            requestShutdown: {
                core.requestShutdown()
            }
        )
    }

    public convenience init(
        registrations: [AnyDistributedActorTypeRegistration],
        codecRegistry: ActorDistributedCodecRegistry = ActorDistributedCodecRegistry(),
        actorIdentitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        self.init(
            codecRegistry: codecRegistry,
            actorIdentitySource: actorIdentitySource,
            router: router,
            transports: transports,
            configuration: configuration,
            callOptions: callOptions
        )
        for registration in registrations {
            try register(registration)
        }
    }

    public convenience init<Bootstrap: SwiftActorSystemBootstrap>(
        bootstrap: Bootstrap.Type,
        actorIdentitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        self.init(
            actorIdentitySource: actorIdentitySource,
            router: router,
            transports: transports,
            configuration: configuration,
            callOptions: callOptions
        )
        try registerBootstrap(Bootstrap.self)
    }

    public func registerCodec<Value: Codable & Sendable>(
        _ type: Value.Type,
        typeID: ActorTypeID,
        codec: ActorGeneratedCodec<Value>
    ) throws {
        try withMutableRegistrations {
            try codecs.register(type, typeID: typeID, codec: codec)
        }
    }

    public func register(_ registration: AnyDistributedActorTypeRegistration) throws {
        try withMutableRegistrations {
            try actorTypes.register(registration)
            Self.bootstrapRegistrationAudit?.record(registration)
        }
    }

    public func registerBootstrap(
        _ bootstrap: any SwiftActorSystemBootstrap.Type
    ) throws {
        guard !Self.isRegisteringBootstrap else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation(
                    "Actor bootstraps must declare nested bootstraps as dependencies"
                )
            )
        }
        try bootstrapRegistration.withLock { _ in
            let bootstrapObjectIdentifier = ObjectIdentifier(bootstrap)
            let isAlreadyInstalled = try registrationState.withLock { state in
                guard !state.isTerminated else {
                    throw ActorSystemError.shuttingDown
                }
                return state.installedBootstraps.contains(bootstrapObjectIdentifier)
            }
            guard !isAlreadyInstalled else {
                return
            }
            let installedCheckpoint = try registrationState.withLock {
                state -> BootstrapRegistrationCheckpoint in
                guard !state.isTerminated else {
                    throw ActorSystemError.shuttingDown
                }
                guard !state.isSealed else {
                    throw ActorSystemError.alreadyStarted
                }
                guard !state.transactionInProgress else {
                    throw ActorSystemError.overloaded
                }
                state.transactionInProgress = true
                return BootstrapRegistrationCheckpoint(
                    bootstraps: state.installedBootstraps,
                    identifiers: state.installedBootstrapIdentifiers,
                    actorOwners: state.bootstrapOwnerByActorTypeID
                )
            }
            let codecCheckpoint = codecs.checkpoint()
            let actorCheckpoint = actorTypes.checkpoint()
            do {
                let registrationOrder = try bootstrapRegistrationOrder(
                    root: bootstrap,
                    excluding: installedCheckpoint.bootstraps,
                    installedIdentifiers: installedCheckpoint.identifiers
                )
                for bootstrap in registrationOrder {
                    try actorTypes.validateBootstrapDeclaration(
                        bootstrap.actorTypeDescriptors,
                        bootstrapIdentifier: bootstrap.bootstrapIdentifier
                    )
                }
                var actorOwners = installedCheckpoint.actorOwners
                try Self.$isRegisteringBootstrap.withValue(true) {
                    for bootstrap in registrationOrder {
                        let audit = BootstrapRegistrationAudit()
                        try Self.$bootstrapRegistrationAudit.withValue(audit) {
                            try bootstrap.register(in: self)
                        }
                        try actorTypes.validateBootstrapRegistrations(
                            audit.registrations,
                            declaredDescriptors: bootstrap.actorTypeDescriptors,
                            bootstrapIdentifier: bootstrap.bootstrapIdentifier
                        )
                        try codecs.validateBootstrapCodecCoverage(
                            for: bootstrap.actorTypeDescriptors,
                            bootstrapIdentifier: bootstrap.bootstrapIdentifier
                        )
                        let bootstrapObjectIdentifier = ObjectIdentifier(bootstrap)
                        for descriptor in bootstrap.actorTypeDescriptors {
                            guard actorOwners[descriptor.id] == nil else {
                                throw ActorSystemError.invalidFrame(
                                    ActorProtocolViolation(
                                        "Actor type ID \(descriptor.id.high):\(descriptor.id.low) is owned by more than one bootstrap"
                                    )
                                )
                            }
                            actorOwners[descriptor.id] = bootstrapObjectIdentifier
                        }
                    }
                }
                registrationState.withLock { state in
                    state.installedBootstraps.formUnion(
                        registrationOrder.map { ObjectIdentifier($0) }
                    )
                    for bootstrap in registrationOrder {
                        state.installedBootstrapIdentifiers[bootstrap.bootstrapIdentifier] =
                            ObjectIdentifier(bootstrap)
                    }
                    state.bootstrapOwnerByActorTypeID = actorOwners
                    state.transactionInProgress = false
                }
            } catch {
                codecs.restore(codecCheckpoint)
                actorTypes.restore(actorCheckpoint)
                registrationState.withLock { state in
                    state.installedBootstraps = installedCheckpoint.bootstraps
                    state.installedBootstrapIdentifiers = installedCheckpoint.identifiers
                    state.bootstrapOwnerByActorTypeID = installedCheckpoint.actorOwners
                    state.transactionInProgress = false
                }
                throw error
            }
        }
    }

    public func start() async throws {
        try registrationState.withLock { state in
            guard !state.isTerminated else {
                throw ActorSystemError.shuttingDown
            }
            guard !state.transactionInProgress else {
                throw ActorSystemError.overloaded
            }
            state.isSealed = true
        }
        do {
            try await lifecycle.start()
        } catch let error as ActorSystemError where error == .alreadyStarted {
            throw error
        } catch {
            _ = await requestShutdown()
            throw error
        }
    }

    public func requestShutdown() async -> ActorSystemTermination {
        bootstrapRegistration.withLock { _ in
            registrationState.withLock { state in
                state.isTerminated = true
                state.isSealed = true
            }
        }
        let removedActors = localRegistrations.withLock { _ in
            localActors.removeAll()
        }
        _ = removedActors
        return await lifecycle.requestShutdown()
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }

    public func assignID<Act>(_ actorType: Act.Type) -> ActorID
    where Act: DistributedActor, Act.ID == ActorID {
        assignID(for: actorType)
    }

    public func assignID<Act>(for actorType: Act.Type) -> ActorID
    where Act: DistributedActor, Act.ID == ActorAddress {
        do {
            try registerAutomaticBootstrapIfAvailable(for: actorType)
            guard let registration = try stableRegistration(for: actorType) else {
                preconditionFailure(
                    "The distributed actor type must be registered before an instance is created"
                )
            }
            return ActorAddress(
                type: registration.descriptor.id,
                identity: actorIdentitySource.nextIdentity(for: registration.descriptor.id)
            )
        } catch {
            preconditionFailure("Distributed actor identity assignment failed: \(error)")
        }
    }

    public func actorReady<Act>(_ actor: Act)
    where Act: DistributedActor, Act.ID == ActorID {
        registerLocal(actor)
    }

    public func registerLocal<Act>(_ actor: Act)
    where Act: DistributedActor, Act.ID == ActorAddress {
        do {
            guard let registration = try stableRegistration(for: Act.self) else {
                preconditionFailure(
                    "The distributed actor type must be registered before an instance is created"
                )
            }
            guard actor.id.type == registration.descriptor.id else {
                preconditionFailure("The distributed actor identity has the wrong actor type ID")
            }
            let target = registration.makeTarget(
                actor: actor,
                codecs: codecs,
                configuration: configuration
            )
            try localRegistrations.withLock { _ in
                try localActors.register(actor, address: actor.id)
                do {
                    try directory.register(target)
                } catch {
                    _ = localActors.unregister(address: actor.id)
                    throw error
                }
            }
        } catch {
            preconditionFailure("Distributed actor registration failed: \(error)")
        }
    }

    public func resignID(_ id: ActorID) {
        unregisterLocal(id)
    }

    public func unregisterLocal(_ id: ActorAddress) {
        let removed = localRegistrations.withLock { _ in
            (
                directory.unregister(address: id),
                localActors.unregister(address: id)
            )
        }
        _ = removed
    }

    public func resolve<Act>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorID {
        try resolveLocal(id: id, as: actorType)
    }

    public func resolveLocal<Act>(
        id: ActorAddress,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorAddress {
        try registerAutomaticBootstrapIfAvailable(for: actorType)
        guard let registration = try stableRegistration(for: actorType),
              registration.descriptor.id == id.type
        else {
            throw ActorSystemError.actorNotFound(id)
        }
        return localRegistrations.withLock { _ in
            localActors.actor(at: id, as: actorType)
        }
    }

    public func makeInvocationEncoder() -> InvocationEncoder {
        ActorDistributedInvocationEncoder(
            prepareEncoding: { [self] swiftTypeID in
                try prepareStableEncoding(for: swiftTypeID)
            }
        )
    }

    public func remoteCall<Act, Err, Res>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type,
        returning: Res.Type
    ) async throws -> Res
    where Act: DistributedActor,
          Act.ID == ActorID,
          Err: Error,
          Res: Codable & Sendable {
        let registration = try registration(for: Act.self)
        guard let method = registration.aliases.methodID(
            forCompilerTarget: target.identifier
        ) else {
            throw ActorSystemError.encodingFailed
        }
        let payload = try invocation.consumePayload()
        let result: ActorInvocationResult
        do {
            result = try await core.invoke(
                ActorInvocation(
                    recipient: actor.id,
                    method: method,
                    schemaFingerprint: registration.descriptor.schemaFingerprint,
                    payload: payload
                ),
                options: callOptions
            )
        } catch let failure as ActorApplicationFailure {
            throw try codecs.decodeError(
                Err.self,
                from: failure,
                options: configuration.portableDecodingOptions
            )
        }
        return try codecs.decode(
            Res.self,
            from: result.payload,
            options: configuration.portableDecodingOptions
        )
    }

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws
    where Act: DistributedActor, Act.ID == ActorID, Err: Error {
        let registration = try registration(for: Act.self)
        guard let method = registration.aliases.methodID(
            forCompilerTarget: target.identifier
        ) else {
            throw ActorSystemError.encodingFailed
        }
        let payload = try invocation.consumePayload()
        do {
            let result = try await core.invoke(
                ActorInvocation(
                    recipient: actor.id,
                    method: method,
                    schemaFingerprint: registration.descriptor.schemaFingerprint,
                    payload: payload
                ),
                options: callOptions
            )
            guard result.payload.isEmpty else {
                throw ActorSystemError.decodingFailed
            }
        } catch let failure as ActorApplicationFailure {
            throw try codecs.decodeError(
                Err.self,
                from: failure,
                options: configuration.portableDecodingOptions
            )
        }
    }

    private func registration<Act>(
        for actorType: Act.Type
    ) throws -> AnyDistributedActorTypeRegistration
    where Act: DistributedActor {
        guard let registration = try stableRegistration(for: actorType) else {
            throw ActorSystemError.encodingFailed
        }
        return registration
    }

    private func bootstrapRegistrationOrder(
        root: any SwiftActorSystemBootstrap.Type,
        excluding installed: Set<ObjectIdentifier>,
        installedIdentifiers: [String: ObjectIdentifier]
    ) throws -> [any SwiftActorSystemBootstrap.Type] {
        var identifiers = installedIdentifiers
        var visiting: Set<ObjectIdentifier> = []
        var visited = installed
        var ordered: [any SwiftActorSystemBootstrap.Type] = []

        func visit(_ bootstrap: any SwiftActorSystemBootstrap.Type) throws {
            let objectIdentifier = ObjectIdentifier(bootstrap)
            guard !visited.contains(objectIdentifier) else {
                return
            }
            guard visiting.insert(objectIdentifier).inserted else {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation(
                        "Actor bootstrap dependency graph contains a cycle at \(bootstrap.bootstrapIdentifier)"
                    )
                )
            }
            if let existing = identifiers[bootstrap.bootstrapIdentifier],
               existing != objectIdentifier {
                throw ActorSystemError.invalidFrame(
                    ActorProtocolViolation(
                        "Actor bootstrap identifier \(bootstrap.bootstrapIdentifier) is duplicated"
                    )
                )
            }
            identifiers[bootstrap.bootstrapIdentifier] = objectIdentifier
            for dependency in bootstrap.dependencies.sorted(by: {
                $0.bootstrapIdentifier < $1.bootstrapIdentifier
            }) {
                try visit(dependency)
            }
            visiting.remove(objectIdentifier)
            visited.insert(objectIdentifier)
            ordered.append(bootstrap)
        }

        try visit(root)
        return ordered
    }

    private func withMutableRegistrations<Result>(
        _ operation: () throws -> Result
    ) throws -> Result {
        if Self.isRegisteringBootstrap {
            return try operation()
        }
        return try registrationState.withLock { state in
            guard !state.isTerminated else {
                throw ActorSystemError.shuttingDown
            }
            guard !state.isSealed else {
                throw ActorSystemError.alreadyStarted
            }
            guard !state.transactionInProgress else {
                throw ActorSystemError.overloaded
            }
            return try operation()
        }
    }

    private func stableRegistration<Act>(
        for actorType: Act.Type
    ) throws -> AnyDistributedActorTypeRegistration?
    where Act: DistributedActor {
        precondition(
            !Self.isRegisteringBootstrap,
            "Actor bootstrap registration cannot construct or resolve actors"
        )
        return try registrationState.withLock { state in
            guard !state.isTerminated else {
                throw ActorSystemError.shuttingDown
            }
            guard !state.transactionInProgress else {
                throw ActorSystemError.overloaded
            }
            return actorTypes.registration(for: actorType)
        }
    }

    private func registerAutomaticBootstrapIfAvailable<Act>(
        for actorType: Act.Type
    ) throws where Act: DistributedActor {
        precondition(
            !Self.isRegisteringBootstrap,
            "Actor bootstrap registration cannot construct or resolve actors"
        )
        guard let provider = actorType as? any SwiftActorSystemBootstrapProvider.Type else {
            return
        }
        try registerBootstrap(provider.actorSystemBootstrap)
    }

    private func prepareStableEncoding(
        for swiftTypeID: ObjectIdentifier
    ) throws -> ActorDistributedCodecRegistry.PreparedEncoding {
        try registrationState.withLock { state in
            guard !state.transactionInProgress else {
                throw ActorSystemError.overloaded
            }
            return try codecs.prepareEncoding(swiftTypeID: swiftTypeID)
        }
    }
}

private final class BootstrapRegistrationAudit: Sendable {
    private let storage = Mutex<[AnyDistributedActorTypeRegistration]>([])

    var registrations: [AnyDistributedActorTypeRegistration] {
        storage.withLock { $0 }
    }

    func record(_ registration: AnyDistributedActorTypeRegistration) {
        storage.withLock { $0.append(registration) }
    }
}
