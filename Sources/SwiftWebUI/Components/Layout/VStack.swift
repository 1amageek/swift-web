import SwiftHTML

public struct VStack<Content: HTML>: WebUIAttributeComponent {
    private let spacing: Space?
    private let alignment: HorizontalAlignment
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Space? = nil,
        @HTMLBuilder content: () -> Content
    ) {
        self.spacing = spacing
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-vstack",
                styles: Style {
                    .gap(stackSpacingValue(spacing))
                    .alignItems(alignment.rawValue)
                },
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(spacing: spacing, alignment: alignment, attributes: self.attributes + attributes, content: content)
    }

    private init(spacing: Space?, alignment: HorizontalAlignment, attributes: [HTMLAttribute], content: Content) {
        self.spacing = spacing
        self.alignment = alignment
        self.attributes = attributes
        self.content = content
    }
}
