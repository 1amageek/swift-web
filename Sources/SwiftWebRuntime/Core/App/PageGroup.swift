
public struct PageGroup<Content: Scene>: Scene, _PrimitiveScene {
    private let path: RoutePath
    private let content: Content

    public init(
        _ path: String = "/",
        @SceneBuilder content: () -> Content
    ) {
        self.path = RoutePath(path)
        self.content = content()
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        try await SceneRenderer.render(content, in: context.grouped(path))
    }
}
