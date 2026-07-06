
struct _AnyScene {
    private let makeScene: (_SceneContext) async throws -> Void

    init<Content: Scene>(_ scene: Content) {
        self.makeScene = { context in
            try await _SceneRenderer.make(scene, in: context)
        }
    }

    func _makeScene(in context: _SceneContext) async throws {
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
        self.scenes = groups.flatMap(\.scenes)
    }

    init(_ groups: SceneGroup...) {
        self.init(groups)
    }

    func _makeScene(in context: _SceneContext) async throws {
        for scene in scenes {
            try await scene._makeScene(in: context)
        }
    }
}
