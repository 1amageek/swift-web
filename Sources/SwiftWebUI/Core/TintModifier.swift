import SwiftHTML

public struct TintModifier<S: ShapeStyle>: ComponentModifier {
    private let style: S

    init(_ style: S) {
        self.style = style
    }

    @Environment(\.theme) private var theme
    @Environment(\.styleSystem) private var styleSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.controlState) private var controlState

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.environment(\.tint, resolvedTint)
    }

    private var resolvedTint: String {
        style.resolve(in: StyleResolutionContext(
            theme: theme,
            styleSystem: styleSystem,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: controlState
        )).cssValue
    }
}
