import SwiftHTML

public struct TintModifier<ShapeStyle: WebShapeStyle>: ComponentModifier {
    private let style: ShapeStyle

    init(_ style: ShapeStyle) {
        self.style = style
    }

    @Environment(\.theme) private var theme
    @Environment(\.designStyle) private var designStyle
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
            designStyle: designStyle,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: controlState
        )).cssValue
    }
}
