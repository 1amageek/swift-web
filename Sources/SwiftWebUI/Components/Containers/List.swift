import SwiftHTML

public struct List<Content: HTML>: WebUIAttributeComponent {
    private let spacing: Space
    private let attributes: [HTMLAttribute]
    private let content: Content
    @Environment(\.listStyle) private var listStyle

    public init(
        spacing: Space = .small,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName("swui-list", listStyle.className, LayoutClass.fillHorizontal),
                styles: .gap(spacing.rawValue),
                extra: [.role("list")] + attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(spacing: spacing, attributes: self.attributes + attributes, content: content)
    }

    private init(spacing: Space, attributes: [HTMLAttribute], content: Content) {
        self.spacing = spacing
        self.attributes = attributes
        self.content = content
    }
}
