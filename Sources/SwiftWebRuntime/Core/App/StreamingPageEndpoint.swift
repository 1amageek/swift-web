
public struct StreamingPageEndpoint<Page: StreamingPage>: Scene, _PrimitiveScene {
    private let path: String

    public init(_ page: Page.Type, path: String) {
        self.path = path
    }

    func _makeScene(in context: _SceneContext) async throws {
        StreamingPageRoute.register(Page.self, on: context.routes, path: path)
    }
}
