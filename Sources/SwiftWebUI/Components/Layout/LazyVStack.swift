import SwiftHTML

public struct LazyVStack<Content: HTML>: WebUIAttributeComponent {
    private let gap: String
    private let alignment: HorizontalAlignment
    private let pinnedViews: PinnedScrollableViews
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
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
        alignment: HorizontalAlignment = .center,
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
                class: "swui-lazy-vstack",
                styles: Style {
                    .gap(gap)
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
            gap: gap,
            alignment: alignment,
            pinnedViews: pinnedViews,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        gap: String,
        alignment: HorizontalAlignment,
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
