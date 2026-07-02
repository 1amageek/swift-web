import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

public struct LazyHGrid<Content: HTML>: WebUIAttributeComponent {
    private let rows: [GridItem]
    private let alignment: VerticalAlignment
    private let gap: StackGap
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        rows: [GridItem],
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.gap = stackGap(spacing)
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    /// Token-named spacing convenience over the theme spacing scale.
    /// Disfavored so `spacing: .none` resolves to `Double?.none` (the default
    /// system spacing, matching SwiftUI's `nil`) instead of `Space.none`.
    @_disfavoredOverload
    public init(
        rows: [GridItem],
        alignment: VerticalAlignment = .center,
        spacing: Space,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.gap = stackGap(spacing)
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: styleClasses(
                    .swuiLazyHGrid,
                    gap.className,
                    alignment.alignItemsClassName
                ).rawValue,
                styles: Style {
                    .gridTemplateRows(gridTemplateTracks(rows))
                    .gridAutoFlow("column")
                    if let value = gap.cssValue {
                        .gap(value)
                    }
                    // Uniform GridItem.alignment lowers onto the container and
                    // overrides the grid's own alignment classes (the atomic
                    // declarations are emitted after the base stylesheet).
                    if let itemAlignment = uniformGridItemAlignment(rows) {
                        .justifyItems(itemAlignment.horizontal.rawValue)
                        .alignItems(itemAlignment.vertical.rawValue)
                    }
                },
                extra: lazyAttributes(axis: "horizontal-grid", pinnedViews: pinnedViews) + attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            rows: rows,
            alignment: alignment,
            gap: gap,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        rows: [GridItem],
        alignment: VerticalAlignment,
        gap: StackGap,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.gap = gap
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.content = content
    }
}
