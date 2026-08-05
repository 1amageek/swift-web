
public struct PageRouteScene<Route: PageRoute>: Scene, _PrimitiveScene {
    private let route: Route

    public init(_ route: Route) {
        self.route = route
    }

    func _renderScene(in context: SceneRenderingContext) async throws {
        try await route._registerPageActions(
            in: PageActionRegistrationContext(
                runtime: context.runtime,
                routes: context.routes
            )
        )
        SwiftWebActorRenderContext.withValue(context.actorBindings) {
            route.register(on: context.routes)
        }
    }
}
