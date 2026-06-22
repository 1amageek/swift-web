/// A background material that adapts to the active theme and design style.
///
/// `Material` is SwiftWebUI's canonical translucency primitive, mirroring
/// SwiftUI's `Material` (`.ultraThinMaterial` … `.bar`). A material resolves to
/// the shared `swui-material` recipe plus a per-level modifier class; the level
/// only varies the fill translucency. In solid design styles (`swiftWeb`,
/// `material`) every level renders as an opaque surface, so component code is
/// style-independent: it always composes a material and the design style decides
/// whether that reads as glass or as a plain surface.
public struct Material: ShapeStyle, Sendable, Equatable {
    public enum Level: String, Sendable, Equatable, CaseIterable {
        case ultraThin
        case thin
        case regular
        case thick
        case ultraThick
        case bar

        var className: String {
            switch self {
            case .ultraThin: MaterialClass.ultraThin
            case .thin: MaterialClass.thin
            case .regular: MaterialClass.regular
            case .thick: MaterialClass.thick
            case .ultraThick: MaterialClass.ultraThick
            case .bar: MaterialClass.bar
            }
        }
    }

    public let level: Level

    public init(level: Level) {
        self.level = level
    }

    /// The class tokens this material contributes to a surface element.
    var classNames: [String] {
        [MaterialClass.material, level.className]
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        // The recipe is class-driven; an empty cssValue keeps the resolver from
        // emitting an inline `background` that would shadow the class rule.
        ResolvedStyle(cssValue: "", classNames: classNames)
    }
}

public extension ShapeStyle where Self == Material {
    static var ultraThinMaterial: Material { Material(level: .ultraThin) }
    static var thinMaterial: Material { Material(level: .thin) }
    static var regularMaterial: Material { Material(level: .regular) }
    static var thickMaterial: Material { Material(level: .thick) }
    static var ultraThickMaterial: Material { Material(level: .ultraThick) }
    static var bar: Material { Material(level: .bar) }
}
