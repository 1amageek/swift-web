import SwiftHTML

public extension WebUIAttributeMutableHTML {
    func foregroundStyle<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle
    ) -> ResolvedWebStyleContent<Self, ShapeStyle> {
        ResolvedWebStyleContent(content: self, property: .foreground, style: style)
    }

    func backgroundStyle<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle
    ) -> ResolvedWebStyleContent<Self, ShapeStyle> {
        ResolvedWebStyleContent(content: self, property: .background, style: style)
    }

    func border<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle,
        width: WebUILength = 1
    ) -> ResolvedWebStyleContent<Self, ShapeStyle> {
        ResolvedWebStyleContent(content: self, property: .border(width: width), style: style)
    }

    func webStyle(_ style: Style) -> AttributeAppliedContent<Self> {
        applyingAttributes([styleAttribute(style)])
    }

    func webStyle(@StyleBuilder _ content: () -> Style) -> AttributeAppliedContent<Self> {
        webStyle(content())
    }
}

public extension HTML {
    func foregroundStyle<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle
    ) -> ModifiedContent<Self, WebStyleModifier<ShapeStyle>> {
        modifier(WebStyleModifier(property: .foreground, style: style))
    }

    func backgroundStyle<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle
    ) -> ModifiedContent<Self, WebStyleModifier<ShapeStyle>> {
        modifier(WebStyleModifier(property: .background, style: style))
    }

    func tint<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle
    ) -> ModifiedContent<Self, TintModifier<ShapeStyle>> {
        modifier(TintModifier(style))
    }

    func border<ShapeStyle: WebShapeStyle>(
        _ style: ShapeStyle,
        width: WebUILength = 1
    ) -> ModifiedContent<Self, WebStyleModifier<ShapeStyle>> {
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
