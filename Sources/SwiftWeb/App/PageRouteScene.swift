import Vapor

public struct PageRouteScene<Route: PageRoute>: Scene, _PrimitiveScene {
    private let route: Route

    public init(_ route: Route) {
        self.route = route
    }

    func _makeScene(in context: _SceneContext) async throws {
        try await route.registerPageOwnedServices(on: context.application, routes: context.routes)
        SwiftWebActorRenderContext.withValue(context.actorBindings) {
            route.register(on: context.routes)
        }
    }
}
