import SwiftHTML

public struct LazyHGrid<Content: HTML>: WebUIAttributeComponent {
    private let rows: [GridItem]
    private let alignment: VerticalAlignment
    private let gap: String
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
        self.gap = stackSpacingValue(spacing)
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    /// Token-named spacing convenience over the design-system spacing scale.
    public init(
        rows: [GridItem],
        alignment: VerticalAlignment = .center,
        spacing: Space,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.gap = stackSpacingValue(spacing)
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-lazy-hgrid",
                styles: Style {
                    .gridTemplateRows(gridTemplateTracks(rows))
                    .gridAutoFlow("column")
                    .gap(gap)
                    .alignItems(alignment.rawValue)
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
        gap: String,
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
