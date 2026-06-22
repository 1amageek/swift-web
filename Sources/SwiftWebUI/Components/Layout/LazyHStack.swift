import SwiftHTML

public struct LazyHStack<Content: HTML>: WebUIAttributeComponent {
    private let gap: String
    private let alignment: VerticalAlignment
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.gap = stackSpacingValue(spacing)
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = []
        self.content = content()
    }

    /// Token-named spacing convenience over the design-system spacing scale.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Space,
        pinnedViews: PinnedScrollableViews = [],
        @HTMLBuilder content: () -> Content
    ) {
        self.gap = stackSpacingValue(spacing)
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
                class: "swui-lazy-hstack",
                styles: Style {
                    .gap(gap)
                    .alignItems(alignment.rawValue)
                },
                extra: lazyAttributes(axis: "horizontal", pinnedViews: pinnedViews) + attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            gap: gap,
            alignment: alignment,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        gap: String,
        alignment: VerticalAlignment,
        pinnedViews: PinnedScrollableViews,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.gap = gap
        self.alignment = alignment
        self.pinnedViews = pinnedViews
        self.attributes = attributes
        self.content = content
    }
}
