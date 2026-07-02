/// A background material that adapts to the active color scheme and design style.
///
/// `Material` is SwiftWebUI's frosted-vibrancy primitive, mirroring SwiftUI's
/// `Material` (`.ultraThinMaterial` … `.bar`): a wide backdrop blur that
/// *obscures* the content behind it, with the level varying the fill
/// translucency. It is distinct from `Glass`, which refracts and reveals the
/// backdrop. In a solid design style (`swiftWeb`) every level renders as an
/// opaque surface; in the glass default it reads as frosted glass.
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
    package var classNames: [String] {
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
