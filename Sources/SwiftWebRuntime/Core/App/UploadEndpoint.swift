
public struct UploadEndpoint<Action: UploadAction>: Scene, _PrimitiveScene {
    private let path: String
    private let bodyStrategy: HTTPBodyStreamStrategy

    public init(
        _ action: Action.Type,
        path: String,
        body: HTTPBodyStreamStrategy = .collect
    ) {
        self.path = path
        self.bodyStrategy = body
    }

    func _makeScene(in context: _SceneContext) async throws {
        UploadRoute.post(Action.self, on: context.routes, path: path, body: bodyStrategy)
    }
}
