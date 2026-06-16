import SwiftHTML

public struct LazyVStack<Content: HTML>: WebUIAttributeComponent {
    private let spacing: Space?
    private let alignment: HorizontalAlignment
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Space? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-lazy-vstack",
                styles: Style {
                    .gap(stackSpacingValue(spacing))
                    .alignItems(alignment.rawValue)
                },
                extra: lazyAttributes(axis: "vertical", pinnedViews: pinnedViews) + attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            spacing: spacing,
            alignment: alignment,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        spacing: Space?,
        alignment: HorizontalAlignment,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.content = content
    }
}
