import SwiftHTML

public struct Grid<Content: HTML>: WebUIAttributeComponent {
    private let minColumnWidth: String
    private let spacing: Space
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        minColumnWidth: String = "280px",
        spacing: Space = .large,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.minColumnWidth = minColumnWidth
        self.spacing = spacing
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid \(LayoutClass.fillHorizontal)",
                styles: Style {
                    .gridTemplateColumns("repeat(auto-fit, minmax(\(minColumnWidth), 1fr))")
                    .gap(spacing.rawValue)
                },
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            minColumnWidth: minColumnWidth,
            spacing: spacing,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(minColumnWidth: String, spacing: Space, attributes: [HTMLAttribute], content: Content) {
        self.minColumnWidth = minColumnWidth
        self.spacing = spacing
        self.attributes = attributes
        self.content = content
    }
}
