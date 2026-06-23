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
    // A rounded-rectangle *height field*: a white plateau on black, inset so a
    // blur leaves the centre flat and slopes only at the (rounded) edge. The
    // filter turns this into a normal map with Sobel gradients, so the
    // refraction bends the backdrop radially at the rim and tapers smoothly
    // around the rounded corners — unlike two crossed linear ramps, whose
    // corners fold into a bright caustic. `preserveAspectRatio='none'` stretches
    // it to each element, so the lens follows the surface's shape and size.
    private static let shapeMaskSVG = """
    <svg xmlns='http://www.w3.org/2000/svg' width='100' height='100' preserveAspectRatio='none'>\
    <rect width='100' height='100' fill='black'/>\
    <rect x='3' y='3' width='94' height='94' rx='30' fill='white'/>\
    </svg>
    """

    private static var shapeMaskDataURI: String {
        let encoded = shapeMaskSVG
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
        <feImage href="\(shapeMaskDataURI)" x="0" y="0" width="100%" height="100%" \
        preserveAspectRatio="none" result="swui-glass-shape"/>\
        <feGaussianBlur in="swui-glass-shape" stdDeviation="14" result="swui-glass-height"/>\
        <feConvolveMatrix in="swui-glass-height" order="3" preserveAlpha="true" divisor="2.2" \
        bias="0.5" kernelMatrix="-1 0 1 -2 0 2 -1 0 1" result="swui-glass-gx"/>\
        <feConvolveMatrix in="swui-glass-height" order="3" preserveAlpha="true" divisor="2.2" \
        bias="0.5" kernelMatrix="-1 -2 -1 0 0 0 1 2 1" result="swui-glass-gy"/>\
        <feColorMatrix in="swui-glass-gx" type="matrix" \
        values="1 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 0 1" result="swui-glass-rmap"/>\
        <feColorMatrix in="swui-glass-gy" type="matrix" \
        values="0 0 0 0 0 0 1 0 0 0 0 0 0 0 0 0 0 0 0 1" result="swui-glass-gmap"/>\
        <feBlend in="swui-glass-rmap" in2="swui-glass-gmap" mode="screen" result="swui-glass-map"/>\
        <feDisplacementMap in="SourceGraphic" in2="swui-glass-map" scale="42" \
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
