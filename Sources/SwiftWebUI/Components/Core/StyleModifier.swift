import SwiftWebUITheme
import SwiftHTML

public struct StyleModifier: ComponentModifier {
    private let property: StyleProperty
    private let style: AnyShapeStyle
    private let ignoredSafeAreaEdges: Edge.Set?

    @usableFromInline
    init<S: ShapeStyle>(
        property: StyleProperty,
        style: S,
        ignoredSafeAreaEdges: Edge.Set? = nil
    ) {
        self.property = property
        self.style = AnyShapeStyle(style)
        self.ignoredSafeAreaEdges = ignoredSafeAreaEdges
    }

    @Environment({ $0.theme }) private var theme: Theme
    @Environment({ $0.colorScheme }) private var colorScheme: ColorScheme
    @Environment({ $0.layoutDirection }) private var layoutDirection: LayoutDirection
    @Environment({ $0.controlState }) private var controlState: ControlState
    @Environment({ $0.isEnabled }) private var isEnabled: Bool

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
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
            theme: theme,
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
