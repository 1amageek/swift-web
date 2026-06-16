import SwiftHTML

public struct WebStyleModifier<ShapeStyle: WebShapeStyle>: ComponentModifier {
    private let property: WebStyleProperty
    private let style: ShapeStyle

    init(property: WebStyleProperty, style: ShapeStyle) {
        self.property = property
        self.style = style
    }

    @Environment(\.theme) private var theme
    @Environment(\.designStyle) private var designStyle
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.controlState) private var controlState
    @Environment(\.isEnabled) private var isEnabled

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        Element(
            "span",
            attributes: mergedAttributes(
                class: className,
                styles: styleValue,
                extra: []
            )
        ) {
            content
        }
    }

    private var resolvedStyle: ResolvedStyle {
        style.resolve(in: StyleResolutionContext(
            theme: theme,
            designStyle: designStyle,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: resolvedControlState
        ))
    }

    private var resolvedControlState: ControlState {
        ControlState(
            isEnabled: isEnabled,
            isPressed: controlState.isPressed,
            isFocused: controlState.isFocused,
            isSelected: controlState.isSelected
        )
    }

    private var styleValue: Style {
        property.style(for: resolvedStyle)
    }

    private var className: String {
        (["swui-modifier", "swui-style"] + resolvedStyle.classNames)
            .joined(separator: " ")
    }
}
