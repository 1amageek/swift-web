import SwiftHTML

public struct ResolvedWebStyleContent<Content: WebUIAttributeMutableHTML, ShapeStyle: WebShapeStyle>: Component, WebUIAttributeMutableHTML {
    private let content: Content
    private let property: WebStyleProperty
    private let style: ShapeStyle
    private let attributes: [HTMLAttribute]

    init(
        content: Content,
        property: WebStyleProperty,
        style: ShapeStyle,
        attributes: [HTMLAttribute] = []
    ) {
        self.content = content
        self.property = property
        self.style = style
        self.attributes = attributes
    }

    @Environment(\.theme) private var theme
    @Environment(\.styleSystem) private var styleSystem
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.controlState) private var controlState
    @Environment(\.isEnabled) private var isEnabled

    @HTMLBuilder
    public var body: some HTML {
        content.addingAttributes(resolvedAttributes + attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            content: content,
            property: property,
            style: style,
            attributes: self.attributes + attributes
        )
    }

    private var resolvedAttributes: [HTMLAttribute] {
        let resolvedStyle = style.resolve(in: StyleResolutionContext(
            theme: theme,
            styleSystem: styleSystem,
            colorScheme: colorScheme,
            layoutDirection: layoutDirection,
            controlState: resolvedControlState
        ))
        var attributes: [HTMLAttribute] = []
        if !resolvedStyle.classNames.isEmpty {
            attributes.append(.class(resolvedStyle.classNames.joined(separator: " ")))
        }
        let styleValue = property.style(for: resolvedStyle)
        if !styleValue.isEmpty {
            attributes.append(styleAttribute(styleValue))
        }
        return attributes
    }

    private var resolvedControlState: ControlState {
        ControlState(
            isEnabled: isEnabled,
            isPressed: controlState.isPressed,
            isFocused: controlState.isFocused,
            isSelected: controlState.isSelected
        )
    }
}
