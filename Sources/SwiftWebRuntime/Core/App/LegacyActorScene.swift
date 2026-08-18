#if SWIFTWEB_LEGACY_ACTORS
import SwiftWebActors

@available(*, deprecated, message: "Use ActorScene with a concrete ActorSystemReference actor")
public struct LegacyActorScene<Content: Scene, ActorType: LegacySwiftWebActorExporting>: Scene, _PrimitiveScene {
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
        LegacyActorInvocationEndpoint.registerIfNeeded(
            in: context.runtime,
            actorSystem: context.legacyActorSystem
        )
        try await SceneRenderer.render(content, in: context.adding(actor))
    }
}

public extension Scene {
    @available(*, deprecated, message: "Use actor(_:) with a concrete ActorSystemReference actor")
    func actor<ActorType: LegacySwiftWebActorExporting>(_ actor: ActorType) -> some Scene {
        LegacyActorScene(content: self, actor: actor)
    }
}
#endif
