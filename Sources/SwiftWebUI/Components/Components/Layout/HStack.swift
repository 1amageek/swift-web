import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

public struct HStack: AttributeComponent {
    private let gap: StackGap
    private let alignment: VerticalAlignment
    private let attributes: [HTMLAttribute]
    private let childContent: ComponentContent

    public init<Content: Component>(
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        @ComponentBuilder content: () -> Content
    ) {
        self.gap = stackGap(spacing)
        self.alignment = alignment
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    /// Token-named spacing convenience over the theme spacing scale.
    /// Disfavored so `spacing: .none` resolves to `Double?.none` (the default
    /// system spacing, matching SwiftUI's `nil`) instead of `Space.none`.
    @_disfavoredOverload
    public init<Content: Component>(
        alignment: VerticalAlignment = .center,
        spacing: Space,
        @ComponentBuilder content: () -> Content
    ) {
        self.gap = stackGap(spacing)
        self.alignment = alignment
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: styleClasses(.swuiHStack, gap.className, alignment.alignItemsClassName).rawValue,
                styles: Style {
                    if let value = gap.cssValue {
                        .gap(value)
                    }
                },
                extra: attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(gap: gap, alignment: alignment, attributes: self.attributes + attributes, content: childContent)
    }

    private init(
        gap: StackGap,
        alignment: VerticalAlignment,
        attributes: [HTMLAttribute],
        content: ComponentContent
    ) {
        self.gap = gap
        self.alignment = alignment
        self.attributes = attributes
        self.childContent = content
    }
}
