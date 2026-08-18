#if SWIFTWEB_LEGACY_ACTORS
import Distributed
import SwiftWebActors

/// A scene that presents a group of identically structured distributed
/// actors, one per identity — like `WindowGroup` presents a group of
/// identically structured windows.
///
///     var body: some Scene {
///         LegacyActorGroup {
///             SupportAgent(actorSystem: actorSystem)
///         }
///     }
///
/// Nothing is created at boot. The factory runs once per identity, when the
/// first message addressed to that identity arrives (and again after the
/// host evicts the instance). The new instance is bound to the targeted ID.
///
/// Declaring an `LegacyActorGroup` also registers the actor invocation endpoint
/// (`/_swiftweb/actors/invoke`) on the host, so the group's actors are
/// reachable without further wiring.
@available(*, deprecated, message: "Use ActorGroup with a concrete actor using WebActorSystem")
public struct LegacyActorGroup<ActorType: DistributedActor>: Scene, Sendable, _PrimitiveScene
where ActorType.ActorSystem == LegacyWebActorSystem {
    private let factory: @Sendable (LegacyWebActorSystem) -> ActorType
    private let scope: ActorScope?
    private let passivation: ActorPassivationPolicy?

    /// The factory receives the app's actor system, so it captures no app
    /// state: `LegacyActorGroup { SupportAgent(actorSystem: $0) }`.
    public init(scope: ActorScope? = nil, _ factory: @escaping @Sendable (LegacyWebActorSystem) -> ActorType) {
        self.factory = factory
        self.scope = scope
        self.passivation = nil
    }

    /// For factories that capture a `Sendable` actor system themselves.
    public init(scope: ActorScope? = nil, _ factory: @escaping @Sendable () -> ActorType) {
        self.factory = { _ in factory() }
        self.scope = scope
        self.passivation = nil
    }

    private init(
        factory: @escaping @Sendable (LegacyWebActorSystem) -> ActorType,
        scope: ActorScope?,
        passivation: ActorPassivationPolicy?
    ) {
        self.factory = factory
        self.scope = scope
        self.passivation = passivation
    }

    /// Overrides when this group's idle actors passivate. Composing with a
    /// `.transient` scope is a configuration error surfaced at scene build.
    public func passivation(_ policy: ActorPassivationPolicy) -> LegacyActorGroup {
        LegacyActorGroup(factory: factory, scope: scope, passivation: policy)
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        if let scope, scope.isTransient, passivation != nil {
            throw ActorSceneConfigurationError.transientScopeCannotPassivate(
                contract: LegacyWebActorSystem.contract(for: ActorType.self)
            )
        }
        let factory = self.factory
        let actorSystem = context.legacyActorSystem
        context.legacyActorSystem.registerActivator(
            for: ActorType.self,
            environment: context.environment
        ) {
            _ = factory(actorSystem)
        }
        LegacyActorInvocationEndpoint.registerIfNeeded(
            in: context.runtime,
            actorSystem: context.legacyActorSystem
        )
        if let scope {
            context.legacyActorSystem.registerScopeAuthorization(
                scope.authorization(),
                forContract: LegacyWebActorSystem.contract(for: ActorType.self)
            )
        }
        if let passivation {
            context.legacyActorSystem.registerPassivationPolicy(
                passivation,
                forContract: LegacyWebActorSystem.contract(for: ActorType.self)
            )
        }
    }
}
#endif
