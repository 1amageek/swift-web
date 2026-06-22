import SwiftHTML

public struct HStack<Content: HTML>: WebUIAttributeComponent {
    private let gap: String
    private let alignment: VerticalAlignment
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Double? = nil,
        @HTMLBuilder content: () -> Content
    ) {
        self.gap = stackSpacingValue(spacing)
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    /// Token-named spacing convenience over the design-system spacing scale.
    public init(
        alignment: VerticalAlignment = .center,
        spacing: Space,
        @HTMLBuilder content: () -> Content
    ) {
        self.gap = stackSpacingValue(spacing)
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-hstack",
                styles: Style {
                    .gap(gap)
                    .alignItems(alignment.rawValue)
                },
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(gap: gap, alignment: alignment, attributes: self.attributes + attributes, content: content)
    }

    private init(gap: String, alignment: VerticalAlignment, attributes: [HTMLAttribute], content: Content) {
        self.gap = gap
        self.alignment = alignment
        self.attributes = attributes
        self.content = content
    }
}
