import SwiftHTML

public struct Pane<Content: HTML>: WebUIAttributeComponent {
    private let span: Int
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        span: Int,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.span = max(span, 1)
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid-pane",
                styles: .custom("grid-column", "span \(span)"),
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(span: span, attributes: self.attributes + attributes, content: content)
    }

    private init(span: Int, attributes: [HTMLAttribute], content: Content) {
        self.span = span
        self.attributes = attributes
        self.content = content
    }
}
