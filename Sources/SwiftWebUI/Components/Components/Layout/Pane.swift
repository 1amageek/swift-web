import SwiftWebUITheme
import SwiftHTML

public struct Pane<Content: Component>: AttributeComponent {
    private let span: Int
    private let attributes: [HTMLAttribute]
    private let childContent: Content

    public init(
        span: Int,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.span = max(span, 1)
        self.attributes = attributes
        self.childContent = content()
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid-pane",
                styles: .gridColumn("span \(span)"),
                extra: attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(span: span, attributes: self.attributes + attributes, content: childContent)
    }

    private init(span: Int, attributes: [HTMLAttribute], content: Content) {
        self.span = span
        self.attributes = attributes
        self.childContent = content
    }
}
