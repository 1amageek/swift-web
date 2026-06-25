import SwiftHTML

public struct ForegroundStylesModifier: ComponentModifier {
    private let styles: [AnyShapeStyle]

    init(_ styles: [AnyShapeStyle]) {
        self.styles = styles
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

    private var resolvedStyles: [ResolvedStyle] {
        styles.map { style in
            style.resolve(in: StyleResolutionContext(
                styleSystem: styleSystem,
                colorScheme: colorScheme,
                layoutDirection: layoutDirection,
                controlState: resolvedControlState
            ))
        }
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
        let resolved = resolvedStyles
        var style = Style()
        if let primary = resolved.first {
            style.append(WebStyleProperty.foreground.style(for: primary))
        }
        // The primary level paints `color`; every level is also published as a
        // `--swui-foreground-{primary,secondary,tertiary,…}` custom property so
        // descendant content can opt into the hierarchy (mirroring how SwiftUI's
        // hierarchical foreground styles propagate through the environment).
        for (index, resolvedStyle) in resolved.enumerated() where !resolvedStyle.cssValue.isEmpty {
            style.append(.custom("--swui-foreground-\(foregroundStyleName(at: index))", resolvedStyle.cssValue))
        }
        return style
    }

    private var className: String {
        (
            [
                "swui-modifier",
                "swui-style",
                HTMLModifierRole.textStyle.className,
                WebStyleProperty.foreground.modifierClassName,
            ] + resolvedStyles.flatMap(\.classNames)
        )
        .joined(separator: " ")
    }

    private func foregroundStyleName(at index: Int) -> String {
        switch index {
        case 0:
            "primary"
        case 1:
            "secondary"
        case 2:
            "tertiary"
        default:
            "level-\(index + 1)"
        }
    }
}

public struct ShapeBackgroundStyleModifier<S: ShapeStyle>: ComponentModifier {
    private let style: S
    private let shape: Shape

    init(style: S, shape: Shape) {
        self.style = style
        self.shape = shape
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
        var style = WebStyleProperty.background.style(for: resolvedStyle)
        style.append(.borderRadius(shape.cornerRadiusValue))
        return style
    }

    private var className: String {
        (
            [
                "swui-modifier",
                "swui-style",
                HTMLModifierRole.box.className,
                WebStyleProperty.background.modifierClassName,
                "swui-style-shaped-background",
            ] + resolvedStyle.classNames
        )
        .joined(separator: " ")
    }
}

public extension HTML {
    func foregroundStyle<S: ShapeStyle>(
        _ style: S
    ) -> ModifiedContent<Self, WebStyleModifier<S>> {
        modifier(WebStyleModifier(property: .foreground, style: style))
    }

    func foregroundStyle<Primary: ShapeStyle, Secondary: ShapeStyle>(
        _ primary: Primary,
        _ secondary: Secondary
    ) -> ModifiedContent<Self, ForegroundStylesModifier> {
        modifier(ForegroundStylesModifier([
            AnyShapeStyle(primary),
            AnyShapeStyle(secondary),
        ]))
    }

    func foregroundStyle<Primary: ShapeStyle, Secondary: ShapeStyle, Tertiary: ShapeStyle>(
        _ primary: Primary,
        _ secondary: Secondary,
        _ tertiary: Tertiary
    ) -> ModifiedContent<Self, ForegroundStylesModifier> {
        modifier(ForegroundStylesModifier([
            AnyShapeStyle(primary),
            AnyShapeStyle(secondary),
            AnyShapeStyle(tertiary),
        ]))
    }

    func background<S: ShapeStyle>(
        _ style: S,
        ignoresSafeAreaEdges edges: Edge.Set = .all
    ) -> ModifiedContent<Self, WebStyleModifier<S>> {
        modifier(WebStyleModifier(property: .background, style: style, ignoredSafeAreaEdges: edges))
    }

    func background<S: ShapeStyle>(
        _ style: S,
        in shape: Shape
    ) -> ModifiedContent<Self, ShapeBackgroundStyleModifier<S>> {
        modifier(ShapeBackgroundStyleModifier(style: style, shape: shape))
    }

    func background(
        in shape: Shape
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.borderRadius(shape.cornerRadiusValue))
        ]))
    }

    func backgroundStyle<S: ShapeStyle>(
        _ style: S
    ) -> ModifiedContent<Self, WebStyleModifier<S>> {
        background(style)
    }

    func tint<S: ShapeStyle>(
        _ style: S
    ) -> ModifiedContent<Self, TintModifier<S>> {
        modifier(TintModifier(style))
    }

    func border<S: ShapeStyle>(
        _ style: S,
        width: Length = 1
    ) -> ModifiedContent<Self, WebStyleModifier<S>> {
        modifier(WebStyleModifier(property: .border(width: width), style: style))
    }

    func controlSize(_ size: ControlSize) -> ModifiedContent<Self, ControlSizeModifier> {
        modifier(ControlSizeModifier(size))
    }

    func disabled(_ isDisabled: Bool = true) -> ModifiedContent<Self, DisabledModifier> {
        modifier(DisabledModifier(isDisabled))
    }

    func webStyle(_ style: Style) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(style)]))
    }

    func webStyle(@StyleBuilder _ content: () -> Style) -> ModifiedContent<Self, HTMLAttributeModifier> {
        webStyle(content())
    }
}
