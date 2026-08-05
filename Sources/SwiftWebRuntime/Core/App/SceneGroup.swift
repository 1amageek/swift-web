
struct _AnyScene {
    private let makeScene: (SceneRenderingContext) async throws -> Void

    init<Content: Scene>(_ scene: Content) {
        self.makeScene = { context in
            try await SceneRenderer.render(scene, in: context)
        }
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        try await makeScene(context)
    }
}

public struct SceneGroup: Scene, _PrimitiveScene {
    private let scenes: [_AnyScene]

    init() {
        self.scenes = []
    }

    init<Content: Scene>(_ scene: Content) {
        self.scenes = [_AnyScene(scene)]
    }

    init(_ groups: [SceneGroup]) {
        self.scenes = groups.flatMap { $0.scenes }
    }

    init(_ groups: SceneGroup...) {
        self.init(groups)
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        for scene in scenes {
            try await scene._renderScene(in: context)
        }
    }
}
