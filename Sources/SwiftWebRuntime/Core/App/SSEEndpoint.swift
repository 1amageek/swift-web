import Vapor

public struct SSEEndpoint<RouteType: SSERoute>: Scene, _PrimitiveScene {
    private let path: String

    public init(_ route: RouteType.Type, path: String) {
        self.path = path
    }

    func _makeScene(in context: _SceneContext) async throws {
        SSERouteBuilder.register(RouteType.self, on: context.routes, path: path)
    }
}
