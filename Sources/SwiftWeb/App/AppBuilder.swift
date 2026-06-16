@resultBuilder
public enum AppBuilder {
    public static func buildBlock(_ components: any AppContent...) -> AppContentGroup {
        AppContentGroup(components)
    }

    public static func buildOptional(_ component: (any AppContent)?) -> AppContentGroup {
        AppContentGroup(component.map { [$0] } ?? [])
    }

    public static func buildEither(first component: any AppContent) -> any AppContent {
        component
    }

    public static func buildEither(second component: any AppContent) -> any AppContent {
        component
    }
}
