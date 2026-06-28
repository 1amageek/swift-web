import SwiftWebUITheme
import SwiftHTML

public struct ZStack<Content: HTML>: WebUIAttributeComponent {
    private let alignment: Alignment
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: Alignment = .center,
        @HTMLBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-zstack",
                styles: Style {
                    .justifyItems(alignment.justifyContent)
                    .alignItems(alignment.alignItems)
                    .textAlign(alignment.textAlign)
                },
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(alignment: alignment, attributes: self.attributes + attributes, content: content)
    }

    private init(alignment: Alignment, attributes: [HTMLAttribute], content: Content) {
        self.alignment = alignment
        self.attributes = attributes
        self.content = content
    }
}
