import ActorSystemCore
import SwiftWebActors

public struct ActorScene<Content: Scene, ActorType: ActorSystemReference>: Scene, _PrimitiveScene
where ActorType.ActorSystem == WebActorSystem {
    private let content: Content
    private let actor: ActorType

    public init(_ actor: ActorType, @SceneBuilder content: () -> Content) {
        self.content = content()
        self.actor = actor
    }

    init(content: Content, actor: ActorType) {
        self.content = content
        self.actor = actor
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        context.runtime.requireActorSystem()
        #if SWIFTWEB_ACTORS
        try await context.actorSystem.actorHost.registerBound(address: actor.id)
        ActorFrameInvocationEndpoint.registerIfNeeded(
            in: context.runtime,
            actorSystem: context.actorSystem
        )
        #endif
        let scope = context.actorBindings.adding(actor)
        let modified = context.replacing(
            routes: ActorBindingRoutesBuilder(
                base: context.routes,
                scope: scope
            ),
            environment: context.environment,
            actorBindings: scope
        )
        try await SwiftWebActorRenderContext.withValue(scope) {
            try await SceneRenderer.render(content, in: modified)
        }
    }
}

public extension Scene {
    func actor<ActorType: ActorSystemReference>(_ actor: ActorType) -> some Scene
    where ActorType.ActorSystem == WebActorSystem {
        ActorScene(content: self, actor: actor)
    }

    #if SWIFTWEB_ACTORS || hasFeature(Embedded)
    /// Binds one logical identity of a concrete actor type to this scene.
    func actor<ActorType: ActorSystemReference>(
        _ actorType: ActorType.Type,
        identity: String
    ) -> some Scene where ActorType.ActorSystem == WebActorSystem {
        ActorReferenceScene(
            content: self,
            actorType: actorType,
            identity: identity
        )
    }
    #endif
}

#if SWIFTWEB_ACTORS || hasFeature(Embedded)
public extension PageRoute {
    /// Binds one logical identity of a concrete actor type to this page route.
    func actor<ActorType: ActorSystemReference>(
        _ actorType: ActorType.Type,
        identity: String
    ) -> some Scene where ActorType.ActorSystem == WebActorSystem {
        PageRouteScene(self).actor(actorType, identity: identity)
    }
}
#endif
