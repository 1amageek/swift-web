#if SWIFTWEB_ACTORS
import Distributed
import SwiftWebActors

/// A scene that presents a group of identically structured distributed
/// actors, one per identity — like `WindowGroup` presents a group of
/// identically structured windows.
///
///     var body: some Scene {
///         ActorGroup {
///             SupportAgent(actorSystem: actorSystem)
///         }
///     }
///
/// Nothing is created at boot. The factory runs once per identity, when the
/// first message addressed to that identity arrives (and again after the
/// host evicts the instance). The new instance is bound to the targeted ID.
///
/// Declaring an `ActorGroup` also registers the actor invocation endpoint
/// (`/_swiftweb/actors/invoke`) on the host, so the group's actors are
/// reachable without further wiring.
public struct ActorGroup<ActorType: DistributedActor>: Scene, Sendable, _PrimitiveScene
where ActorType.ActorSystem == WebActorSystem {
    private let factory: @Sendable (WebActorSystem) -> ActorType

    /// The factory receives the app's actor system, so it captures no app
    /// state: `ActorGroup { SupportAgent(actorSystem: $0) }`.
    public init(_ factory: @escaping @Sendable (WebActorSystem) -> ActorType) {
        self.factory = factory
    }

    /// For factories that capture a `Sendable` actor system themselves.
    public init(_ factory: @escaping @Sendable () -> ActorType) {
        self.factory = { _ in factory() }
    }

    func _makeScene(in context: _SceneContext) async throws {
        let factory = self.factory
        let actorSystem = context.actorSystem
        context.actorSystem.registerActivator(
            for: ActorType.self,
            environment: context.environment
        ) {
            _ = factory(actorSystem)
        }
        ActorInvocationEndpoint.registerIfNeeded(
            on: context.application,
            actorSystem: context.actorSystem
        )
    }
}
#endif
