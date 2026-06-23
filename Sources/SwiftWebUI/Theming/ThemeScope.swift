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
            .data("theme", theme.name),
            .data("style-system", styleSystem.id),
            .class("swui-root")
        ) {
            content
        }
    }
}

private enum ThemeScopeAssets {
    // A displacement *normal map*: neutral (128,128) in the centre so the middle
    // of the glass is undistorted, with the red channel ramping to the left/right
    // edges and the green channel to the top/bottom edges. Fed to
    // feDisplacementMap it lenses the live backdrop at the rim — the real
    // "Liquid Glass" refraction — rather than the uniform frosted wobble a
    // turbulence map produces. `preserveAspectRatio='none'` stretches the map to
    // each element's box, so the lens follows the surface's shape and size.
    private static let displacementMapSVG = """
    <svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' preserveAspectRatio='none'>\
    <defs>\
    <linearGradient id='gx' x1='0' y1='0' x2='1' y2='0'>\
    <stop offset='0' stop-color='rgb(0,0,0)'/><stop offset='0.28' stop-color='rgb(128,0,0)'/>\
    <stop offset='0.72' stop-color='rgb(128,0,0)'/><stop offset='1' stop-color='rgb(255,0,0)'/>\
    </linearGradient>\
    <linearGradient id='gy' x1='0' y1='0' x2='0' y2='1'>\
    <stop offset='0' stop-color='rgb(0,0,0)'/><stop offset='0.28' stop-color='rgb(0,128,0)'/>\
    <stop offset='0.72' stop-color='rgb(0,128,0)'/><stop offset='1' stop-color='rgb(0,255,0)'/>\
    </linearGradient>\
    </defs>\
    <rect width='100' height='100' fill='rgb(0,0,0)'/>\
    <rect width='100' height='100' fill='url(#gx)' style='mix-blend-mode:screen'/>\
    <rect width='100' height='100' fill='url(#gy)' style='mix-blend-mode:screen'/>\
    </svg>
    """

    private static var displacementDataURI: String {
        let encoded = displacementMapSVG
            .replacingOccurrences(of: "<", with: "%3C")
            .replacingOccurrences(of: ">", with: "%3E")
            .replacingOccurrences(of: "#", with: "%23")
        return "data:image/svg+xml," + encoded
    }

    static var refractionFilterMarkup: String {
        """
        <svg class="swui-glass-filters" aria-hidden="true" focusable="false" width="0" height="0" \
        style="position:absolute;width:0;height:0;overflow:hidden">\
        <filter id="swui-glass-refraction" x="0%" y="0%" width="100%" height="100%" \
        color-interpolation-filters="sRGB">\
        <feImage href="\(displacementDataURI)" x="0" y="0" width="100%" height="100%" \
        preserveAspectRatio="none" result="swui-glass-map"/>\
        <feDisplacementMap in="SourceGraphic" in2="swui-glass-map" scale="30" \
        xChannelSelector="R" yChannelSelector="G"/>\
        </filter></svg>
        """
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
