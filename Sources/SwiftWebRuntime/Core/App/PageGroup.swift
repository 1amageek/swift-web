
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

    func _makeScene(in context: _SceneContext) async throws {
        try await _SceneRenderer.make(content, in: context.grouped(path))
    }
}
