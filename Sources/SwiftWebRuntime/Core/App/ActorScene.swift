#if SWIFTWEB_ACTORS
import SwiftWebActors

public struct ActorScene<Content: Scene, ActorType: SwiftWebActorExporting>: Scene, _PrimitiveScene {
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
        try await SceneRenderer.render(content, in: context.adding(actor))
    }
}

public extension Scene {
    func actor<ActorType: SwiftWebActorExporting>(_ actor: ActorType) -> some Scene {
        ActorScene(content: self, actor: actor)
    }
}
#endif
