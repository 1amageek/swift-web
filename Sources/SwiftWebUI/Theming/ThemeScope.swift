import SwiftHTML

struct ThemeScope<Content: HTML>: Component {
    @Environment(\.theme) private var theme: Theme
    @Environment(\.designStyle) private var designStyle: DesignStyle

    private let content: Content

    init(@HTMLBuilder _ content: () -> Content) {
        self.content = content()
    }

    @HTMLBuilder
    var body: some HTML {
        style {
            rawHTML(ThemeStylesheet.stylesheet(for: theme, designStyle: designStyle).cssText)
        }
        div(
            .data("swift-web-ui-theme", theme.name),
            .data("swift-web-ui-design-style", designStyle.id),
            .class("swui-root")
        ) {
            content
        }
    }
}

public extension HTML {
    func environment(
        _ keyPath: WritableKeyPath<EnvironmentValues, Theme>,
        _ value: Theme
    ) -> some HTML {
        EnvironmentModifier(keyPath, value) {
            ThemeScope {
                self
            }
        }
    }
}
