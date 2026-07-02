import Vapor

public struct EmptyScene: Scene, _PrimitiveScene {
    public init() {}

    func _makeScene(in context: _SceneContext) async throws {}
}
