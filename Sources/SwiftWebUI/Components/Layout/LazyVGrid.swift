import SwiftHTML

public struct LazyVGrid<Content: HTML>: WebUIAttributeComponent {
    private let columns: [GridItem]
    private let alignment: HorizontalAlignment
    private let gap: String
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
        self.gap = stackSpacingValue(spacing)
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    /// Token-named spacing convenience over the design-system spacing scale.
    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: Space,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.columns = columns
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
                class: "swui-lazy-vgrid \(LayoutClass.fillHorizontal)",
                styles: Style {
                    .gridTemplateColumns(gridTemplateTracks(columns))
                    .gap(gap)
                    .justifyItems(alignment.rawValue)
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
        gap: String,
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
