import SwiftWebUITheme
import SwiftHTML

public struct TintModifier<S: ShapeStyle>: ComponentModifier {
    private let style: S

    init(_ style: S) {
        self.style = style
    }

    @Environment({ $0.theme }) private var theme: Theme
    @Environment({ $0.colorScheme }) private var colorScheme: ColorScheme
    @Environment({ $0.layoutDirection }) private var layoutDirection: LayoutDirection
    @Environment({ $0.controlState }) private var controlState: ControlState

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.transformEnvironment({ $0.tint = resolvedTint })
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
