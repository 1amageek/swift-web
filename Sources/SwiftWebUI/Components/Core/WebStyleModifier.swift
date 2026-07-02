import SwiftWebUITheme
import SwiftHTML

public struct WebStyleModifier<S: ShapeStyle>: ComponentModifier {
    private let property: WebStyleProperty
    private let style: S
    private let ignoredSafeAreaEdges: Edge.Set?

    init(
        property: WebStyleProperty,
        style: S,
        ignoredSafeAreaEdges: Edge.Set? = nil
    ) {
        self.property = property
        self.style = style
        self.ignoredSafeAreaEdges = ignoredSafeAreaEdges
    }

    @Environment(\.styleSystem) private var styleSystem: StyleSystem
    @Environment(\.colorScheme) private var colorScheme: ColorScheme
    @Environment(\.layoutDirection) private var layoutDirection: LayoutDirection
    @Environment(\.controlState) private var controlState: ControlState
    @Environment(\.isEnabled) private var isEnabled: Bool

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        Element(
            "div",
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
            styleSystem: styleSystem,
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
        var style = property.style(for: resolvedStyle)
        if let ignoredSafeAreaEdges {
            style.append(safeAreaExpansionStyle(edges: ignoredSafeAreaEdges))
        }
        return style
    }

    private var className: String {
        (["swui-modifier", "swui-style", property.modifierRole.className, property.modifierClassName] + resolvedStyle.classNames)
            .joined(separator: " ")
    }
}
