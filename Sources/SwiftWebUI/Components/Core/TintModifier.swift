import SwiftWebUITheme
import SwiftHTML

public struct TintModifier<S: ShapeStyle>: ComponentModifier {
    private let style: S

    init(_ style: S) {
        self.style = style
    }

    @Environment(\.theme) private var theme: Theme
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.layoutDirection) private var layoutDirection: LayoutDirection
    @Environment(\.controlState) private var controlState: ControlState

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.environment(\.tint, resolvedTint)
    }

    private var resolvedTint: Color {
        Color(cssValue: style.resolve(in: StyleResolutionContext(
            theme: theme,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: controlState
        )).cssValue)
    }
}
