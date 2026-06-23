import SwiftHTML

/// A Liquid Glass material applied with `glassEffect(_:in:)`.
///
/// Mirrors SwiftUI's `Glass`: `.regular` and `.clear` pick how much of the
/// backdrop shows through, `.identity` is a no-op, and `.tint(_:)` /
/// `.interactive(_:)` refine the surface. Liquid Glass has its own `swui-glass`
/// recipe — a light blur plus edge-lensing SVG refraction, a specular sheen, and
/// a rim — that *reveals* the backdrop, distinct from `Material`'s frosted blur
/// that obscures it. The variant only selects the fill translucency level.
public struct Glass: Sendable, Equatable {
    enum Variant: Sendable, Equatable {
        case regular
        case clear
        case identity
    }

    var variant: Variant
    var tintColor: String?
    var isInteractive: Bool

    init(variant: Variant, tintColor: String? = nil, isInteractive: Bool = false) {
        self.variant = variant
        self.tintColor = tintColor
        self.isInteractive = isInteractive
    }

    public static let regular = Glass(variant: .regular)
    public static let clear = Glass(variant: .clear)
    public static let identity = Glass(variant: .identity)

    /// Wash the glass with a tint color (a CSS color or `var(--swui-…)` token).
    /// Pass `nil` to clear a previously applied tint.
    public func tint(_ color: String?) -> Glass {
        var copy = self
        copy.tintColor = color
        return copy
    }

    /// Make the glass react to pointer interaction (hover/press highlight).
    public func interactive(_ isEnabled: Bool = true) -> Glass {
        var copy = self
        copy.isInteractive = isEnabled
        return copy
    }

    /// The material level the variant maps to, or `nil` for `.identity`.
    var levelClassName: String? {
        switch variant {
        case .regular: MaterialClass.regular
        case .clear: MaterialClass.ultraThin
        case .identity: nil
        }
    }

    /// The attributes to merge onto a surface, or `nil` for `.identity`.
    func attributes(in shape: Shape) -> [HTMLAttribute]? {
        guard let levelClassName else {
            return nil
        }
        var classes = [MaterialClass.glass, levelClassName]
        if isInteractive {
            classes.append(MaterialClass.interactive)
        }
        var style = Style.borderRadius(shape.cornerRadiusValue)
        if let tintColor {
            style = style.custom("--swui-material-tint", tintColor)
        }
        return [
            .class(classes.joined(separator: " ")),
            styleAttribute(style),
        ]
    }
}
