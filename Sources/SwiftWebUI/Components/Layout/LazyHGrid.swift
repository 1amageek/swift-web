import SwiftHTML

public struct LazyHGrid<Content: HTML>: WebUIAttributeComponent {
    private let rows: [GridItem]
    private let alignment: VerticalAlignment
    private let spacing: Space?
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        rows: [GridItem],
        alignment: VerticalAlignment = .center,
        spacing: Space? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing
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
                    .gap(stackSpacingValue(spacing))
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
            spacing: spacing,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        rows: [GridItem],
        alignment: VerticalAlignment,
        spacing: Space?,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.rows = rows
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.content = content
    }
}
