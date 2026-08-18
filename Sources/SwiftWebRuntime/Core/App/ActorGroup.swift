#if SWIFTWEB_ACTORS
import ActorSystemCore
import SwiftWebActors

/// Registers a concrete distributed actor factory for virtual activation.
/// Actor methods continue to use their ordinary Distributed Actor call surface;
/// this scene only supplies host-side construction policy.
public struct ActorGroup<ActorType: ActorSystemReference>: Scene, Sendable, _PrimitiveScene
where ActorType.ActorSystem == WebActorSystem {
    private let factory: @Sendable (WebActorSystem) throws -> ActorType
    private let scope: ActorScope?
    private let passivationPolicy: ActorPassivationPolicy?

    public init(
        scope: ActorScope? = nil,
        _ factory: @escaping @Sendable (WebActorSystem) throws -> ActorType
    ) {
        self.factory = factory
        self.scope = scope
        self.passivationPolicy = nil
    }

    public init(
        scope: ActorScope? = nil,
        _ factory: @escaping @Sendable () throws -> ActorType
    ) {
        self.factory = { _ in try factory() }
        self.scope = scope
        self.passivationPolicy = nil
    }

    private init(
        factory: @escaping @Sendable (WebActorSystem) throws -> ActorType,
        scope: ActorScope?,
        passivationPolicy: ActorPassivationPolicy?
    ) {
        self.factory = factory
        self.scope = scope
        self.passivationPolicy = passivationPolicy
    }

    public func passivation(_ policy: ActorPassivationPolicy) -> ActorGroup {
        ActorGroup(
            factory: factory,
            scope: scope,
            passivationPolicy: policy
        )
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        let contract = SwiftWebActorContractKey(ActorType.self).rawValue
        if let scope, scope.isTransient, passivationPolicy != nil {
            throw ActorSceneConfigurationError.transientScopeCannotPassivate(
                contract: contract
            )
        }
        context.runtime.requireActorSystem()
        let actorSystem = context.actorSystem
        try actorSystem.registerGeneratedBootstrapIfAvailable(for: ActorType.self)
        let environment = context.environment
        let factory = self.factory
        try await actorSystem.actorHost.register(
            SwiftWebActorFactory(
                ActorType.self,
                activate: { _ in
                    #if !hasFeature(Embedded)
                    return try await EnvironmentValues.withValue(environment) {
                        try factory(actorSystem)
                    }
                    #else
                    return try factory(actorSystem)
                    #endif
                },
                passivate: { address in
                    actorSystem.unregisterLocal(address)
                }
            ),
            authorization: scope?.swiftWebAuthorization(),
            passivation: passivationPolicy
        )
        ActorFrameInvocationEndpoint.registerIfNeeded(
            in: context.runtime,
            actorSystem: actorSystem
        )
    }
}
#endif
