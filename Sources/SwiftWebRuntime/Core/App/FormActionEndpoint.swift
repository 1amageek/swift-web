#if !hasFeature(Embedded)
/// A scene that exposes a typed form action at a fixed path.
public struct FormActionEndpoint<Action: FormAction>: Scene, _PrimitiveScene {
    private let path: RoutePath
    private let bodyStrategy: HTTPBodyStreamStrategy

    public init(
        _ action: Action.Type,
        path: String,
        body: HTTPBodyStreamStrategy = .collect
    ) {
        self.path = RoutePath(path)
        self.bodyStrategy = body
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        FormActionRoute.post(
            Action.self,
            on: context.routes,
            path: path,
            body: bodyStrategy
        )
    }
}
#endif
