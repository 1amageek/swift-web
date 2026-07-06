
@resultBuilder
public enum SceneBuilder {
    public static func buildExpression<Content: Scene>(_ content: Content) -> SceneGroup {
        SceneGroup(content)
    }

    public static func buildExpression<Route: PageRoute>(_ route: Route) -> SceneGroup {
        SceneGroup(PageRouteScene(route))
    }

    public static func buildBlock(_ components: SceneGroup...) -> SceneGroup {
        SceneGroup(components)
    }

    public static func buildOptional(_ component: SceneGroup?) -> SceneGroup {
        component ?? SceneGroup()
    }

    public static func buildEither(first component: SceneGroup) -> SceneGroup {
        component
    }

    public static func buildEither(second component: SceneGroup) -> SceneGroup {
        component
    }

    public static func buildArray(_ components: [SceneGroup]) -> SceneGroup {
        SceneGroup(components)
    }

    public static func buildLimitedAvailability(_ component: SceneGroup) -> SceneGroup {
        component
    }
}
