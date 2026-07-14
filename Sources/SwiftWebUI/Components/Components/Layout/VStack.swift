import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

public struct VStack<Content: HTML>: AttributeComponent {
    private let gap: StackGap
    private let alignment: HorizontalAlignment
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Double? = nil,
        @HTMLBuilder content: () -> Content
    ) {
        self.gap = stackGap(spacing)
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    /// Token-named spacing convenience over the theme spacing scale.
    /// Disfavored so `spacing: .none` resolves to `Double?.none` (the default
    /// system spacing, matching SwiftUI's `nil`) instead of `Space.none`.
    @_disfavoredOverload
    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Space,
        @HTMLBuilder content: () -> Content
    ) {
        self.gap = stackGap(spacing)
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: styleClasses(.swuiVStack, gap.className, alignment.alignItemsClassName).rawValue,
                styles: Style {
                    if let value = gap.cssValue {
                        .gap(value)
                    }
                },
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(gap: gap, alignment: alignment, attributes: self.attributes + attributes, content: content)
    }

    private init(gap: StackGap, alignment: HorizontalAlignment, attributes: [HTMLAttribute], content: Content) {
        self.gap = gap
        self.alignment = alignment
        self.attributes = attributes
        self.content = content
    }
}
