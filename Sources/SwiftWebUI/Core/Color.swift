/// A color shape style, mirroring SwiftUI's `Color`. It is the single concrete
/// color type for the framework: literal colors (`Color(hex:)`,
/// `Color(red:green:blue:opacity:)`, `.white`/`.black`/`.clear`), the semantic
/// theme colors (`.accent`, `.surface`, `.primary`, …, resolving to theme custom
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
    /// `Color.opacity(_:)`. Stays theme-adaptive: `Color.accent.opacity(0.12)`
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

public extension ShapeStyle where Self == Color {
    static var clear: Color { Color(cssValue: "transparent") }
    static var white: Color { Color(cssValue: "#ffffff") }
    static var black: Color { Color(cssValue: "#000000") }

    // Semantic theme colors — resolve to the active theme's custom properties.
    static var primary: Color { Color(cssValue: "var(--swui-text)") }
    static var secondary: Color { Color(cssValue: "var(--swui-text-muted)") }
    static var accent: Color { Color(cssValue: "var(--swui-accent)") }
    static var accentText: Color { Color(cssValue: "var(--swui-accent-text)") }
    static var danger: Color { Color(cssValue: "var(--swui-danger)") }
    static var dangerText: Color { Color(cssValue: "var(--swui-danger-text)") }
    static var background: Color { Color(cssValue: "var(--swui-background)") }
    static var surface: Color { Color(cssValue: "var(--swui-surface)") }
    static var surfaceRaised: Color { Color(cssValue: "var(--swui-surface-raised)") }
    static var border: Color { Color(cssValue: "var(--swui-border)") }
}
