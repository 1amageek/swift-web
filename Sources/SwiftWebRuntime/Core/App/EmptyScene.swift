
public struct EmptyScene: Scene, _PrimitiveScene {
    public init() {}

    func _renderScene(in context: SceneRenderingContext) async throws {}
}
