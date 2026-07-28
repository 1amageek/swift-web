import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

public struct LazyVStack: AttributeComponent {
    private let gap: StackGap
    private let alignment: HorizontalAlignment
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let childContent: ComponentContent

    public init<Content: Component>(
        alignment: HorizontalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @ComponentBuilder content: () -> Content
    ) {
        self.gap = stackGap(spacing)
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    /// Token-named spacing convenience over the theme spacing scale.
    /// Disfavored so `spacing: .none` resolves to `Double?.none` (the default
    /// system spacing, matching SwiftUI's `nil`) instead of `Space.none`.
    @_disfavoredOverload
    public init<Content: Component>(
        alignment: HorizontalAlignment = .center,
        spacing: Space,
        pinnedViews: PinnedScrollableViews = [],
        @ComponentBuilder content: () -> Content
    ) {
        self.gap = stackGap(spacing)
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: styleClasses(.swuiLazyVStack, gap.className, alignment.alignItemsClassName).rawValue,
                styles: Style {
                    if let value = gap.cssValue {
                        .gap(value)
                    }
                },
                extra: lazyAttributes(axis: "vertical", pinnedViews: pinnedViews) + attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            gap: gap,
            alignment: alignment,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: childContent
        )
    }

    private init(
        gap: StackGap,
        alignment: HorizontalAlignment,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: ComponentContent
    ) {
        self.gap = gap
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.childContent = content
    }
}
