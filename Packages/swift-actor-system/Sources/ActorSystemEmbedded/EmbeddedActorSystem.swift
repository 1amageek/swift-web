@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
import Synchronization

public final class EmbeddedActorSystem: Sendable {
    private struct RegistrationState: Sendable {
        var isTerminated = false
    }

    private let directory: ActorDirectory
    private let core: ActorSystemCore
    private let lifecycle: ActorSystemLifecycleCoordinator
    public let configuration: ActorSystemConfiguration
    private let instances = EmbeddedActorInstanceStore()
    private let registrations = Mutex(RegistrationState())
    private let callOptions: ActorCallOptions
    private let identitySource: any ActorIdentitySource

    public init(
        identitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) {
        let directory = ActorDirectory()
        self.directory = directory
        self.callOptions = callOptions
        self.configuration = configuration
        self.identitySource = identitySource
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

    @available(*, deprecated, message: "Place identitySource before router and configuration")
    public convenience init(
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        identitySource: any ActorIdentitySource,
        callOptions: ActorCallOptions = .defaults
    ) {
        self.init(
            identitySource: identitySource,
            router: router,
            transports: transports,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    public func start() async throws {
        try await lifecycle.start()
    }

    public var portableDecodingOptions: ActorPortableDecodingOptions {
        configuration.portableDecodingOptions
    }

    public func requestShutdown() async -> ActorSystemTermination {
        let removedInstances = registrations.withLock { state -> [any EmbeddedActorInstance] in
            state.isTerminated = true
            return instances.removeAll()
        }
        _ = removedInstances
        return await lifecycle.requestShutdown()
    }

    public func shutdown() async throws {
        try await requestShutdown().wait()
    }

    @available(*, deprecated, message: "Use embeddedBackend.register(_:target:)")
    public func register<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        target: any ActorInvocationTarget
    ) throws {
        try registerBackend(instance, target: target)
    }

    func registerBackend<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        target: any ActorInvocationTarget
    ) throws {
        guard target.address.type == target.descriptor.id else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Embedded actor target descriptor does not match its address")
            )
        }
        guard Instance.actorTypeDescriptor.id == target.descriptor.id else {
            throw ActorSystemError.invalidFrame(
                ActorProtocolViolation("Embedded actor instance type does not match its target")
            )
        }
        try registrations.withLock { state in
            guard !state.isTerminated else {
                throw ActorSystemError.shuttingDown
            }
            try instances.register(instance, at: target.address)
            do {
                try directory.register(target)
            } catch {
                _ = instances.unregister(address: target.address)
                throw error
            }
        }
    }

    @available(*, deprecated, message: "Use embeddedBackend.registerGenerated(_:target:)")
    public func registerGenerated<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        target: any ActorInvocationTarget
    ) {
        registerGeneratedBackend(instance, target: target)
    }

    func registerGeneratedBackend<Instance: EmbeddedActorInstance>(
        _ instance: Instance,
        target: any ActorInvocationTarget
    ) {
        precondition(
            target.address.type == target.descriptor.id,
            "Embedded actor target descriptor must match its address"
        )
        do {
            try registerBackend(instance, target: target)
        } catch {
            _ = error
            preconditionFailure("Generated Embedded actor registration failed")
        }
    }

    public func assignID(actorType: ActorTypeID) -> ActorAddress {
        ActorAddress(
            type: actorType,
            identity: identitySource.nextIdentity(for: actorType)
        )
    }

    public func unregister(address: ActorAddress) {
        let removed = registrations.withLock { _ in
            (
                directory.unregister(address: address),
                instances.unregister(address: address)
            )
        }
        _ = removed
    }

    public func location(for address: ActorAddress) -> EmbeddedActorLocation {
        registrations.withLock { _ in
            directory.target(for: address) == nil ? .remote : .local
        }
    }

    public func resolveLocal<Instance: EmbeddedActorInstance>(
        id: ActorAddress,
        as type: Instance.Type
    ) -> Instance? {
        registrations.withLock { _ in
            guard id.type == Instance.actorTypeDescriptor.id else {
                return nil
            }
            return instances.instance(at: id, as: type)
        }
    }

    public func resolve<Instance: EmbeddedActorInstance>(
        id: ActorAddress,
        as type: Instance.Type,
        makeRemote: () -> Instance
    ) throws -> Instance {
        let local = try registrations.withLock { state -> Instance? in
            guard !state.isTerminated else {
                throw ActorSystemError.shuttingDown
            }
            guard id.type == Instance.actorTypeDescriptor.id else {
                throw ActorSystemError.actorNotFound(id)
            }
            return instances.instance(at: id, as: type)
        }
        return local ?? makeRemote()
    }

    public func invoke<Argument: Sendable, Result: Sendable>(
        actor: ActorAddress,
        method: ActorMethodID,
        schemaFingerprint: ActorSchemaFingerprint,
        argument: Argument,
        argumentCodec: ActorGeneratedCodec<Argument>,
        resultCodec: ActorGeneratedCodec<Result>,
        errorCodec: EmbeddedActorErrorCodec? = nil
    ) async throws -> Result {
        try await lifecycle.start()
        let payload = try argumentCodec.encode(argument)
        do {
            let result = try await core.invoke(
                ActorInvocation(
                    recipient: actor,
                    method: method,
                    schemaFingerprint: schemaFingerprint,
                    payload: payload
                ),
                options: callOptions
            )
            return try resultCodec.decode(
                result.payload,
                options: configuration.portableDecodingOptions
            )
        } catch let failure as ActorApplicationFailure {
            guard let errorCodec else {
                throw ActorSystemError.remoteFailure(
                    ActorRemoteFailure(code: ActorSystemErrorCode.remoteFailure.rawValue)
                )
            }
            throw try errorCodec.decode(
                failure,
                options: configuration.portableDecodingOptions
            )
        }
    }

    public func invokeVoid<Argument: Sendable>(
        actor: ActorAddress,
        method: ActorMethodID,
        schemaFingerprint: ActorSchemaFingerprint,
        argument: Argument,
        argumentCodec: ActorGeneratedCodec<Argument>,
        errorCodec: EmbeddedActorErrorCodec? = nil
    ) async throws {
        try await lifecycle.start()
        let payload = try argumentCodec.encode(argument)
        do {
            let result = try await core.invoke(
                ActorInvocation(
                    recipient: actor,
                    method: method,
                    schemaFingerprint: schemaFingerprint,
                    payload: payload
                ),
                options: callOptions
            )
            guard result.payload.isEmpty else {
                throw ActorSystemError.decodingFailed
            }
        } catch let failure as ActorApplicationFailure {
            guard let errorCodec else {
                throw ActorSystemError.remoteFailure(
                    ActorRemoteFailure(code: ActorSystemErrorCode.remoteFailure.rawValue)
                )
            }
            throw try errorCodec.decode(
                failure,
                options: configuration.portableDecodingOptions
            )
        }
    }
}

@available(*, deprecated, renamed: "ActorIdentitySource")
public typealias EmbeddedActorIdentitySource = ActorIdentitySource

public struct EmbeddedActorErrorCodec: Sendable {
    private let decodeFailure: @Sendable (
        ActorApplicationFailure,
        ActorPortableDecodingOptions
    ) throws -> any Error

    public init<Failure: Error & Sendable>(
        typeID: ActorTypeID,
        codec: ActorGeneratedCodec<Failure>
    ) {
        self.decodeFailure = { failure, options in
            guard failure.typeID == typeID else {
                throw ActorSystemError.decodingFailed
            }
            return try codec.decode(failure.payload, options: options)
        }
    }

    public func decode(
        _ failure: ActorApplicationFailure,
        options: ActorPortableDecodingOptions = ActorPortableDecodingOptions()
    ) throws -> any Error {
        try decodeFailure(failure, options)
    }
}
