#if SWIFTWEB_ACTORS
@_spi(ActorSystemLifecycleOwnership) import ActorSystemCore
import ActorSystemDistributed
import Distributed

/// The compiler-facing SwiftWeb distributed actor system.
///
/// All routing, framing, correlation, timeout, cancellation, and codec work is
/// delegated to `SwiftActorSystem`. SwiftWeb host policy is composed with the
/// interceptor supplied through `ActorSystemConfiguration`.
public final class WebActorSystem: DistributedActorSystem, Sendable {
    public typealias ActorID = ActorAddress
    public typealias InvocationEncoder = ActorDistributedInvocationEncoder
    public typealias InvocationDecoder = ActorDistributedInvocationDecoder
    public typealias ResultHandler = ActorDistributedResultHandler
    public typealias SerializationRequirement = Codable & Sendable

    private static let sharedConfiguration = ActorSystemConfiguration(
        sessionIdentitySource: SwiftWebRandomActorSessionIdentitySource()
    )
    private static let sharedRequestTransport: SwiftWebRequestReplyActorTransport = {
        do {
            return try SwiftWebRequestReplyActorTransport(
                maximumPendingRequests: sharedConfiguration.maximumInFlightCalls,
                maximumBufferedFrames: sharedConfiguration.maximumConcurrentInboundCalls,
                maximumPeerEndpoints: sharedConfiguration.maximumTransportEndpoints,
                maximumPeerIdentityBytes: sharedConfiguration.maximumIdentityBytes
            )
        } catch {
            preconditionFailure(
                "The default SwiftWeb HTTP actor transport configuration is invalid: \(error)"
            )
        }
    }()
    private static let sharedWebSocketTransport: SwiftWebWebSocketActorTransport = {
        do {
            return try SwiftWebWebSocketActorTransport(
                configuration: sharedConfiguration
            )
        } catch {
            preconditionFailure(
                "The default SwiftWeb actor transport configuration is invalid: \(error)"
            )
        }
    }()
    public static let shared: WebActorSystem = {
        do {
            return try WebActorSystem(
                transports: [
                    .swiftWebHTTP: sharedRequestTransport,
                    .swiftWebWebSocket: sharedWebSocketTransport,
                ],
                configuration: sharedConfiguration
            )
        } catch {
            preconditionFailure(
                "The default SwiftWeb actor host configuration is invalid: \(error)"
            )
        }
    }()

    package let actorHost: SwiftWebActorHost
    public let configuration: ActorSystemConfiguration
    package let frameCodec: ActorFrameCodec
    public let distributedBackend: SwiftWebDistributedActorBackend
    package let hostingTransportCapability: SwiftWebActorHostingTransportCapability
    private let implementation: SwiftActorSystem
    private let lifecycle: ActorSystemLifecycleCoordinator

    public convenience init(
        codecRegistry: ActorDistributedCodecRegistry = ActorDistributedCodecRegistry(),
        identitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        let configuredActorHost = configuration.inboundInterceptor as? SwiftWebActorHost
        if configuredActorHost == nil,
           configuration.inboundInterceptor is any ActorLocalInvocationClaiming {
            throw SwiftWebActorSystemConfigurationError.conflictingLocalInvocationOwners
        }
        let resolvedActorHost = configuredActorHost ?? SwiftWebActorHost()
        self.init(
            codecRegistry: codecRegistry,
            actorIdentitySource: identitySource,
            router: router,
            transports: transports,
            resolvedActorHost: resolvedActorHost,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    @available(*, deprecated, message: "Use identitySource instead of actorIdentitySource")
    public convenience init(
        codecRegistry: ActorDistributedCodecRegistry = ActorDistributedCodecRegistry(),
        actorIdentitySource: any ActorIdentitySource,
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        try self.init(
            codecRegistry: codecRegistry,
            identitySource: actorIdentitySource,
            router: router,
            transports: transports,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    public convenience init(
        codecRegistry: ActorDistributedCodecRegistry = ActorDistributedCodecRegistry(),
        identitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        actorHost: SwiftWebActorHost,
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        if let configuredActorHost = configuration.inboundInterceptor as? SwiftWebActorHost,
           configuredActorHost !== actorHost {
            throw SwiftWebActorSystemConfigurationError.conflictingActorHosts
        }
        if configuration.inboundInterceptor is any ActorLocalInvocationClaiming,
           configuration.inboundInterceptor as? SwiftWebActorHost == nil {
            throw SwiftWebActorSystemConfigurationError.conflictingLocalInvocationOwners
        }
        self.init(
            codecRegistry: codecRegistry,
            actorIdentitySource: identitySource,
            router: router,
            transports: transports,
            resolvedActorHost: actorHost,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    @available(*, deprecated, message: "Use identitySource instead of actorIdentitySource")
    public convenience init(
        codecRegistry: ActorDistributedCodecRegistry = ActorDistributedCodecRegistry(),
        actorIdentitySource: any ActorIdentitySource,
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        actorHost: SwiftWebActorHost,
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        try self.init(
            codecRegistry: codecRegistry,
            identitySource: actorIdentitySource,
            router: router,
            transports: transports,
            actorHost: actorHost,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    private init(
        codecRegistry: ActorDistributedCodecRegistry,
        actorIdentitySource: any ActorIdentitySource,
        router: any ActorRouter,
        transports: [ActorTransportID: any ActorTransport],
        resolvedActorHost: SwiftWebActorHost,
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions
    ) {
        let inboundInterceptor: any ActorInboundInvocationInterceptor
        if let configuredActorHost = configuration.inboundInterceptor as? SwiftWebActorHost,
           configuredActorHost === resolvedActorHost {
            inboundInterceptor = resolvedActorHost
        } else {
            inboundInterceptor = SwiftWebActorInboundInterceptor(
                configuredInterceptor: configuration.inboundInterceptor,
                actorHost: resolvedActorHost
            )
        }
        let effectiveConfiguration = configuration.replacingInboundInterceptor(
            inboundInterceptor
        )
        self.actorHost = resolvedActorHost
        self.configuration = effectiveConfiguration
        self.frameCodec = ActorFrameCodec(configuration: effectiveConfiguration)
        self.hostingTransportCapability = SwiftWebActorHostingTransportCapability(
            transports: transports
        )
        let implementation = SwiftActorSystem(
            codecRegistry: codecRegistry,
            actorIdentitySource: SwiftWebDistributedActorIdentitySource(
                fallback: actorIdentitySource
            ),
            router: router,
            transports: transports,
            configuration: effectiveConfiguration,
            callOptions: callOptions
        )
        self.implementation = implementation
        self.distributedBackend = SwiftWebDistributedActorBackend(
            implementation: implementation
        )
        self.lifecycle = ActorSystemLifecycleCoordinator(
            start: {
                try await resolvedActorHost.sealConfiguration()
                try await implementation.start()
            },
            requestShutdown: {
                let admission = await resolvedActorHost.requestStopAdmission()
                let implementationTermination = await implementation.requestShutdown()
                return ActorSystemTermination(
                    dependencies: {
                        [admission, implementationTermination]
                    },
                    operation: {
                        let hostTermination = await resolvedActorHost.requestFinishShutdown()
                        try await hostTermination.waitForCompletionAsDependency()
                    }
                )
            }
        )
    }

    public convenience init<Bootstrap: SwiftActorSystemBootstrap>(
        generatedBootstrap: Bootstrap.Type,
        identitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        try self.init(
            identitySource: identitySource,
            router: router,
            transports: transports,
            configuration: configuration,
            callOptions: callOptions
        )
        try distributedBackend.registerGeneratedBootstrap(Bootstrap.self)
    }

    @available(*, deprecated, message: "Use identitySource instead of actorIdentitySource")
    public convenience init<Bootstrap: SwiftActorSystemBootstrap>(
        generatedBootstrap: Bootstrap.Type,
        actorIdentitySource: any ActorIdentitySource,
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        try self.init(
            generatedBootstrap: Bootstrap.self,
            identitySource: actorIdentitySource,
            router: router,
            transports: transports,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    public convenience init<Bootstrap: SwiftActorSystemBootstrap>(
        generatedBootstrap: Bootstrap.Type,
        identitySource: any ActorIdentitySource = SequentialActorIdentitySource(),
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        actorHost: SwiftWebActorHost,
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        try self.init(
            identitySource: identitySource,
            router: router,
            transports: transports,
            actorHost: actorHost,
            configuration: configuration,
            callOptions: callOptions
        )
        try distributedBackend.registerGeneratedBootstrap(Bootstrap.self)
    }

    @available(*, deprecated, message: "Use identitySource instead of actorIdentitySource")
    public convenience init<Bootstrap: SwiftActorSystemBootstrap>(
        generatedBootstrap: Bootstrap.Type,
        actorIdentitySource: any ActorIdentitySource,
        router: any ActorRouter = RejectingActorRouter(),
        transports: [ActorTransportID: any ActorTransport] = [:],
        actorHost: SwiftWebActorHost,
        configuration: ActorSystemConfiguration,
        callOptions: ActorCallOptions = .defaults
    ) throws {
        try self.init(
            generatedBootstrap: Bootstrap.self,
            identitySource: actorIdentitySource,
            router: router,
            transports: transports,
            actorHost: actorHost,
            configuration: configuration,
            callOptions: callOptions
        )
    }

    @available(*, deprecated, message: "Use distributedBackend.registerGeneratedBootstrap(_:)")
    public func registerGeneratedBootstrap(
        _ bootstrap: any SwiftActorSystemBootstrap.Type
    ) throws {
        try distributedBackend.registerGeneratedBootstrap(bootstrap)
    }

    package func registerGeneratedBootstrapIfAvailable<ActorType>(
        for actorType: ActorType.Type
    ) throws where ActorType: ActorSystemReference,
                   ActorType.ActorSystem == WebActorSystem {
        guard let bootstrapProvider = actorType as? any SwiftActorSystemBootstrapProvider.Type else {
            return
        }
        try distributedBackend.registerGeneratedBootstrap(
            bootstrapProvider.actorSystemBootstrap
        )
    }

    @available(*, deprecated, message: "Use distributedBackend.registerCodec(_:typeID:codec:)")
    public func registerCodec<Value: Codable & Sendable>(
        _ type: Value.Type,
        typeID: ActorTypeID,
        codec: ActorGeneratedCodec<Value>
    ) throws {
        try distributedBackend.registerCodec(type, typeID: typeID, codec: codec)
    }

    @available(*, deprecated, message: "Use distributedBackend.register(_:)")
    public func register(_ registration: AnyDistributedActorTypeRegistration) throws {
        try distributedBackend.register(registration)
    }

    public func start() async throws {
        try await lifecycle.start()
    }

    public func requestShutdown() async -> ActorSystemTermination {
        await lifecycle.requestShutdown()
    }

    public func shutdown() async throws {
        try await lifecycle.shutdown()
    }

    public func assignID<Act>(_ actorType: Act.Type) -> ActorID
    where Act: DistributedActor, Act.ID == ActorID {
        implementation.assignID(actorType)
    }

    public func actorReady<Act>(_ actor: Act)
    where Act: DistributedActor, Act.ID == ActorID {
        implementation.actorReady(actor)
    }

    public func resignID(_ id: ActorID) {
        implementation.resignID(id)
    }

    public func unregisterLocal(_ id: ActorAddress) {
        implementation.unregisterLocal(id)
    }

    public func reminders(for id: ActorAddress) -> SwiftWebActorReminders {
        actorHost.reminders(for: id)
    }

    public func deliverReminder(
        _ reminder: SwiftWebActorReminder
    ) async throws {
        try await actorHost.deliverReminder(reminder)
    }

    public func resolve<Act>(
        id: ActorID,
        as actorType: Act.Type
    ) throws -> Act? where Act: DistributedActor, Act.ID == ActorID {
        try implementation.resolve(id: id, as: actorType)
    }

    public func makeInvocationEncoder() -> InvocationEncoder {
        implementation.makeInvocationEncoder()
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
        try await lifecycle.start()
        return try await implementation.remoteCall(
            on: actor,
            target: target,
            invocation: &invocation,
            throwing: throwing,
            returning: returning
        )
    }

    public func remoteCallVoid<Act, Err>(
        on actor: Act,
        target: RemoteCallTarget,
        invocation: inout InvocationEncoder,
        throwing: Err.Type
    ) async throws
    where Act: DistributedActor, Act.ID == ActorID, Err: Error {
        try await lifecycle.start()
        try await implementation.remoteCallVoid(
            on: actor,
            target: target,
            invocation: &invocation,
            throwing: throwing
        )
    }
}

#elseif hasFeature(Embedded)
import ActorSystemCore
import ActorSystemEmbedded

public typealias WebActorSystem = EmbeddedActorSystem

private enum SwiftWebEmbeddedActorSystemHolder {
    static let shared = EmbeddedActorSystem(
        identitySource: SwiftWebEmbeddedActorIdentitySource(),
        configuration: ActorSystemConfiguration(
            sessionIdentitySource: UnavailableActorSessionIdentitySource()
        )
    )
}

public extension EmbeddedActorSystem {
    typealias ActorID = ActorAddress

    static var shared: EmbeddedActorSystem {
        SwiftWebEmbeddedActorSystemHolder.shared
    }
}
#else
import ActorSystemCore

/// The actor-free stand-in compiled when neither Distributed Actors nor the
/// Embedded actor runtime is selected.
public final class WebActorSystem: Sendable {
    public typealias ActorID = ActorAddress

    public static let shared = WebActorSystem()

    public init() {}
}
#endif
