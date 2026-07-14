/// A color shape style, mirroring SwiftUI's `Color`. It is the single concrete
/// color type for the framework: literal colors (`Color(hex:)`,
/// `Color(red:green:blue:opacity:)`, `.white`/`.black`/`.clear`), the semantic
/// semantic colors (`.accent`, `.surface`, `.primary`, …, resolving to root custom
/// properties), and the results of `opacity(_:)`/`mix(with:by:)` are all `Color`,
/// so they compose without type erasure.
public struct Color: ShapeStyle, Sendable, Equatable {
    /// The resolved CSS color value (`#rrggbb`, `rgba(...)`, `var(--swui-…)`,
    /// `color-mix(...)`, or `transparent`).
    public let cssValue: String

    public init(cssValue: String) {
        self.cssValue = cssValue
    }

    /// An sRGB color from components in `0...1`, mirroring SwiftUI's
    /// `Color(red:green:blue:opacity:)`.
    public init(red: Double, green: Double, blue: Double, opacity: Double = 1) {
        func channel(_ value: Double) -> Int {
            Int((Swift.max(0, Swift.min(1, value)) * 255).rounded())
        }
        let alpha = Swift.max(0, Swift.min(1, opacity))
        self.cssValue = "rgba(\(channel(red)), \(channel(green)), \(channel(blue)), \(trimmedNumber(alpha)))"
    }

    /// A color from HSB components in `0...1`, mirroring SwiftUI's
    /// `Color(hue:saturation:brightness:opacity:)`. The components lower to a
    /// CSS `hsl()`/`hsla()` value via the HSB-to-HSL identities.
    public init(hue: Double, saturation: Double, brightness: Double, opacity: Double = 1) {
        let hue = Swift.max(0, Swift.min(1, hue))
        let saturation = Swift.max(0, Swift.min(1, saturation))
        let brightness = Swift.max(0, Swift.min(1, brightness))
        let alpha = Swift.max(0, Swift.min(1, opacity))
        let lightness = brightness * (1 - saturation / 2)
        let hslSaturation: Double
        if lightness <= 0 || lightness >= 1 {
            hslSaturation = 0
        } else {
            hslSaturation = (brightness - lightness) / Swift.min(lightness, 1 - lightness)
        }
        let components = "\(trimmedNumber(hue * 360)), \(trimmedNumber(hslSaturation * 100))%, \(trimmedNumber(lightness * 100))%"
        if alpha < 1 {
            self.cssValue = "hsla(\(components), \(trimmedNumber(alpha)))"
        } else {
            self.cssValue = "hsl(\(components))"
        }
    }

    /// A color from a `0xRRGGBB` literal.
    public init(hex: Int) {
        let clamped = Swift.max(0, Swift.min(hex, 0xFF_FF_FF))
        let hexString = String(clamped, radix: 16, uppercase: false)
        self.cssValue = "#\(String(repeating: "0", count: 6 - hexString.count))\(hexString)"
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        ResolvedStyle(cssValue: cssValue)
    }

    /// The color at the given opacity (clamped to `0...1`), mirroring SwiftUI's
    /// `Color.opacity(_:)`. Stays color-scheme-adaptive: `Color.accent.opacity(0.12)`
    /// fades the resolved accent, and `opacity(0)` is transparent.
    public func opacity(_ opacity: Double) -> Color {
        let alpha = Swift.max(0, Swift.min(1, opacity))
        return Color(cssValue: "color-mix(in srgb, \(cssValue) \(trimmedNumber(alpha * 100))%, transparent)")
    }

    /// A blend toward `other` by `fraction` (`0` = self, `1` = `other`),
    /// mirroring SwiftUI's `Color.mix(with:by:)`.
    public func mix(with other: Color, by fraction: Double) -> Color {
        let amount = Swift.max(0, Swift.min(1, fraction))
        return Color(cssValue: "color-mix(in srgb, \(cssValue), \(other.cssValue) \(trimmedNumber(amount * 100))%)")
    }
}

public extension Color {
    // Hierarchical colors live on the concrete type only, mirroring SwiftUI:
    // an explicit `Color.primary`/`Color.secondary` is a fixed semantic color,
    // while bare `.primary`/`.secondary` in a `ShapeStyle` position resolves to
    // `HierarchicalShapeStyle` and derives from the current foreground.
    static var primary: Color { Color(cssValue: "var(--swui-text)") }
    static var secondary: Color { Color(cssValue: "var(--swui-text-muted)") }
}

public extension ShapeStyle where Self == Color {
    static var clear: Color { Color(cssValue: "transparent") }
    static var white: Color { Color(cssValue: "#ffffff") }
    static var black: Color { Color(cssValue: "#000000") }

    // The standard color palette, adapting between the Apple system palette's
    // light and dark appearances via CSS `light-dark()`.
    static var red: Color { Color(cssValue: "light-dark(rgb(255, 59, 48), rgb(255, 69, 58))") }
    static var orange: Color { Color(cssValue: "light-dark(rgb(255, 149, 0), rgb(255, 159, 10))") }
    static var yellow: Color { Color(cssValue: "light-dark(rgb(255, 204, 0), rgb(255, 214, 10))") }
    static var green: Color { Color(cssValue: "light-dark(rgb(52, 199, 89), rgb(48, 209, 88))") }
    static var mint: Color { Color(cssValue: "light-dark(rgb(0, 199, 190), rgb(99, 230, 226))") }
    static var teal: Color { Color(cssValue: "light-dark(rgb(48, 176, 199), rgb(64, 200, 224))") }
    static var cyan: Color { Color(cssValue: "light-dark(rgb(50, 173, 230), rgb(100, 210, 255))") }
    static var blue: Color { Color(cssValue: "light-dark(rgb(0, 122, 255), rgb(10, 132, 255))") }
    static var indigo: Color { Color(cssValue: "light-dark(rgb(88, 86, 214), rgb(94, 92, 230))") }
    static var purple: Color { Color(cssValue: "light-dark(rgb(175, 82, 222), rgb(191, 90, 242))") }
    static var pink: Color { Color(cssValue: "light-dark(rgb(255, 45, 85), rgb(255, 55, 95))") }
    static var brown: Color { Color(cssValue: "light-dark(rgb(162, 132, 94), rgb(172, 142, 104))") }
    static var gray: Color { Color(cssValue: "light-dark(rgb(142, 142, 147), rgb(142, 142, 147))") }

    // Semantic colors resolve to the active root custom properties.
    static var accent: Color { Color(cssValue: "var(--swui-accent)") }

    /// The app accent color, mirroring SwiftUI's `Color.accentColor`. The
    /// canonical alias for `.accent`.
    static var accentColor: Color { Color(cssValue: "var(--swui-accent)") }
    static var accentText: Color { Color(cssValue: "var(--swui-accent-text)") }
    static var danger: Color { Color(cssValue: "var(--swui-danger)") }
    static var dangerText: Color { Color(cssValue: "var(--swui-danger-text)") }
    static var background: Color { Color(cssValue: "var(--swui-background)") }
    static var surface: Color { Color(cssValue: "var(--swui-surface)") }
    static var surfaceRaised: Color { Color(cssValue: "var(--swui-surface-raised)") }
    static var border: Color { Color(cssValue: "var(--swui-border)") }
}

#if !hasFeature(Embedded)
extension Color: Codable {}
#endif
