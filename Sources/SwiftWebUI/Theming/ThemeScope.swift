import SwiftHTML

struct ThemeScope<Content: HTML>: Component {
    @Environment(\.theme) private var theme: Theme
    @Environment(\.styleSystem) private var styleSystem: StyleSystem

    private let content: Content

    init(@HTMLBuilder _ content: () -> Content) {
        self.content = content()
    }

    @HTMLBuilder
    var body: some HTML {
        style {
            rawHTML(ThemeStylesheet.css(for: theme, styleSystem: styleSystem))
        }
        // The SVG displacement filter the glass refraction overlay references via
        // `backdrop-filter: url(#swui-glass-refraction)`. Emitted once per scope,
        // hidden and inert. Chromium applies it for true refraction; Safari
        // ignores `url()` backdrop-filters and falls back to the base blur.
        rawHTML(ThemeScopeAssets.refractionFilterMarkup)
        div(
            .data("swift-web-ui-theme", theme.name),
            .data("swift-web-ui-style-system", styleSystem.id),
            .class("swui-root")
        ) {
            content
        }
    }
}

private enum ThemeScopeAssets {
    static let refractionFilterMarkup = """
    <svg class="swui-glass-filters" aria-hidden="true" focusable="false" width="0" height="0" \
    style="position:absolute;width:0;height:0;overflow:hidden">\
    <filter id="swui-glass-refraction" x="0%" y="0%" width="100%" height="100%" \
    color-interpolation-filters="sRGB">\
    <feTurbulence type="fractalNoise" baseFrequency="0.009 0.013" numOctaves="2" seed="7" \
    result="swui-glass-noise"/>\
    <feDisplacementMap in="SourceGraphic" in2="swui-glass-noise" scale="16" \
    xChannelSelector="R" yChannelSelector="G"/>\
    </filter></svg>
    """
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
