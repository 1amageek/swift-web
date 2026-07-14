import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

public struct LazyVGrid<Content: HTML>: AttributeComponent {
    private let columns: [GridItem]
    private let alignment: HorizontalAlignment
    private let gap: StackGap
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.columns = columns
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
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: Space,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.columns = columns
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
                    .swuiLazyVGrid,
                    StyleClass(LayoutClass.fillHorizontal),
                    gap.className,
                    alignment.justifyItemsClassName
                ).rawValue,
                styles: Style {
                    .gridTemplateColumns(gridTemplateTracks(columns))
                    if let value = gap.cssValue {
                        .gap(value)
                    }
                    // Uniform GridItem.alignment lowers onto the container and
                    // overrides the grid's own alignment classes (the atomic
                    // declarations are emitted after the base stylesheet).
                    if let itemAlignment = uniformGridItemAlignment(columns) {
                        .justifyItems(itemAlignment.horizontal.rawValue)
                        .alignItems(itemAlignment.vertical.rawValue)
                    }
                },
                extra: lazyAttributes(axis: "vertical-grid", pinnedViews: pinnedViews) + attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            columns: columns,
            alignment: alignment,
            gap: gap,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        columns: [GridItem],
        alignment: HorizontalAlignment,
        gap: StackGap,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.gap = gap
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.content = content
    }
}
