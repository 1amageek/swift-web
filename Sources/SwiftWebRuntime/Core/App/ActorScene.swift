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
        try await SceneRenderer.render(content, in: context.adding(actor))
    }
}

public extension Scene {
    func actor<ActorType: ActorSystemReference>(_ actor: ActorType) -> some Scene
    where ActorType.ActorSystem == WebActorSystem {
        ActorScene(content: self, actor: actor)
    }
}
