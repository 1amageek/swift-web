import SwiftHTML

public struct LazyVGrid<Content: HTML>: WebUIAttributeComponent {
    private let columns: [GridItem]
    private let alignment: HorizontalAlignment
    private let spacing: Space?
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        columns: [GridItem],
        alignment: HorizontalAlignment = .center,
        spacing: Space? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.columns = columns
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
                class: "swui-lazy-vgrid \(LayoutClass.fillHorizontal)",
                styles: Style {
                    .gridTemplateColumns(gridTemplateTracks(columns))
                    .gap(stackSpacingValue(spacing))
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
            spacing: spacing,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        columns: [GridItem],
        alignment: HorizontalAlignment,
        spacing: Space?,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.columns = columns
        self.alignment = alignment
        self.spacing = spacing
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.content = content
    }
}
