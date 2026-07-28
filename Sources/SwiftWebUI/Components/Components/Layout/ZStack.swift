import SwiftWebUITheme
import SwiftHTML

public struct ZStack: AttributeComponent {
    private let alignment: Alignment
    private let attributes: [HTMLAttribute]
    private let childContent: ComponentContent

    public init<Content: Component>(
        alignment: Alignment = .center,
        @ComponentBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    @ComponentBuilder
    public var content: some Component {
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
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(alignment: alignment, attributes: self.attributes + attributes, content: childContent)
    }

    private init(alignment: Alignment, attributes: [HTMLAttribute], content: ComponentContent) {
        self.alignment = alignment
        self.attributes = attributes
        self.childContent = content
    }
}
