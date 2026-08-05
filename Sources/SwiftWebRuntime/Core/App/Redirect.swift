
public struct Redirect: Scene, Sendable, _PrimitiveScene {
    private let source: RoutePath
    private let destination: String

    public init(
        _ source: String,
        to destination: String
    ) {
        self.source = RoutePath(source)
        self.destination = destination
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        let destination = self.destination
        context.routes.get(source.webComponents) { request in
            request.redirect(to: destination)
        }
    }
}
