#if !hasFeature(Embedded)
// Rides the gated streaming subsystem; full profiles only.

public struct StreamingPageEndpoint<Page: StreamingPage>: Scene, _PrimitiveScene {
    private let path: String

    public init(_ page: Page.Type, path: String) {
        self.path = path
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        StreamingPageRoute.register(Page.self, on: context.routes, path: path)
    }
}
#endif
