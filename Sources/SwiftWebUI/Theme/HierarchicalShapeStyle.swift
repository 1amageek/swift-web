/// A shape style that maps to a level of the current foreground hierarchy,
/// mirroring SwiftUI's `HierarchicalShapeStyle`.
///
/// Each level resolves to the `--swui-foreground-…` custom property that the
/// multi-level `foregroundStyle` modifiers publish, falling back to the root
/// text tokens when no hierarchy is in scope. Bare `.primary`/`.secondary` in a
/// `ShapeStyle` position resolve here; an explicit `Color.primary`/
/// `Color.secondary` stays a fixed semantic color.
public struct HierarchicalShapeStyle: ShapeStyle, Sendable, Equatable {
    enum Level: Sendable, Equatable {
        case primary
        case secondary
        case tertiary
        case quaternary
    }

    let level: Level

    init(level: Level) {
        self.level = level
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        ResolvedStyle(cssValue: cssValue)
    }

    var cssValue: String {
        switch level {
        case .primary:
            "var(--swui-foreground-primary, var(--swui-text))"
        case .secondary:
            "var(--swui-foreground-secondary, var(--swui-text-muted))"
        case .tertiary:
            "var(--swui-foreground-tertiary, \(Self.tertiaryFallback))"
        case .quaternary:
            // No fourth-level custom property is published; the quaternary
            // level fades the tertiary level, matching the step between the
            // system tertiary and quaternary label opacities.
            "color-mix(in srgb, var(--swui-foreground-tertiary, \(Self.tertiaryFallback)) 60%, transparent)"
        }
    }

    // No root token exists below `--swui-text-muted`; the tertiary fallback
    // fades the muted text token, matching the step between the system
    // secondary and tertiary label opacities.
    private static let tertiaryFallback = "color-mix(in srgb, var(--swui-text-muted) 50%, transparent)"
}

public extension ShapeStyle where Self == HierarchicalShapeStyle {
    static var primary: HierarchicalShapeStyle { HierarchicalShapeStyle(level: .primary) }
    static var secondary: HierarchicalShapeStyle { HierarchicalShapeStyle(level: .secondary) }
    static var tertiary: HierarchicalShapeStyle { HierarchicalShapeStyle(level: .tertiary) }
    static var quaternary: HierarchicalShapeStyle { HierarchicalShapeStyle(level: .quaternary) }
}
