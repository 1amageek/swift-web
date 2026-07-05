import SwiftWebUITheme
import SwiftHTML

public struct ForegroundStylesModifier: ComponentModifier {
    private let styles: [AnyShapeStyle]

    init(_ styles: [AnyShapeStyle]) {
        self.styles = styles
    }

    @Environment(\.theme) private var theme: Theme
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
                theme: theme,
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
            let name = "--swui-foreground-\(foregroundStyleName(at: index))"
            // A hierarchical style at its own level (e.g. `.secondary` in the
            // second slot) resolves to `var(<name>, …)`. Redeclaring the
            // property in terms of itself is a custom-property cycle in CSS
            // (the declaration becomes invalid); omitting it keeps the
            // inherited level, which is what the identity mapping means.
            if resolvedStyle.cssValue.contains("var(\(name)") {
                continue
            }
            style.append(.custom(name, resolvedStyle.cssValue))
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

    @Environment(\.theme) private var theme: Theme
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

public struct BackgroundStyleModifier<S: ShapeStyle>: ComponentModifier {
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
        content.environment(\.backgroundStyle, resolvedBackgroundStyle)
    }

    private var resolvedBackgroundStyle: String {
        style.resolve(in: StyleResolutionContext(
            theme: theme,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: controlState
        )).cssValue
    }
}

public struct EnvironmentBackgroundModifier: ComponentModifier {
    private let shape: Shape

    init(shape: Shape) {
        self.shape = shape
    }

    @Environment(\.backgroundStyle) private var backgroundStyle: String?

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

    private var styleValue: Style {
        var style = Style.background(backgroundStyle ?? "var(--swui-background)")
        style.append(.borderRadius(shape.cornerRadiusValue))
        return style
    }

    private var className: String {
        [
            "swui-modifier",
            "swui-style",
            HTMLModifierRole.box.className,
            WebStyleProperty.background.modifierClassName,
            "swui-style-shaped-background",
        ]
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

    /// Fill `shape` behind the view with the environment's background style.
    ///
    /// Mirrors SwiftUI `background(in:)`: the fill comes from the nearest
    /// `backgroundStyle(_:)` up the tree, defaulting to the root background
    /// token when none is in scope.
    func background(
        in shape: Shape
    ) -> ModifiedContent<Self, EnvironmentBackgroundModifier> {
        modifier(EnvironmentBackgroundModifier(shape: shape))
    }

    /// Set the background style that `background(in:)` fills with, for this
    /// view and its descendants.
    ///
    /// Mirrors SwiftUI `backgroundStyle(_:)`: it only writes the environment
    /// and paints nothing itself.
    func backgroundStyle<S: ShapeStyle>(
        _ style: S
    ) -> ModifiedContent<Self, BackgroundStyleModifier<S>> {
        modifier(BackgroundStyleModifier(style))
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
