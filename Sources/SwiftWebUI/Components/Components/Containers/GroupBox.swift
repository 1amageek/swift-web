import SwiftWebUITheme
import SwiftHTML

public struct GroupBox: AttributeComponent {
    private let label: ComponentContent
    private let showsLabel: Bool
    private let attributes: [HTMLAttribute]
    private let childContent: ComponentContent

    public init<Content: Component, Label: Component>(
        @ComponentBuilder content: () -> Content,
        @ComponentBuilder label: () -> Label
    ) {
        self.label = HTMLBuilder.buildExpression(label())
        self.showsLabel = true
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "section",
            attributes: mergedAttributes(
                class: "swui-group-box \(MaterialClass.material) \(MaterialClass.regular)",
                extra: attributes
            )
        ) {
            if showsLabel {
                Element("div", attributes: [.class("swui-group-box-title")]) {
                    label
                }
            }
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(label: label, showsLabel: showsLabel, attributes: self.attributes + attributes, content: childContent)
    }

    private init(
        label: ComponentContent,
        showsLabel: Bool,
        attributes: [HTMLAttribute],
        content: ComponentContent
    ) {
        self.label = label
        self.showsLabel = showsLabel
        self.attributes = attributes
        self.childContent = content
    }
}

public extension GroupBox {
    init<Content: Component>(@ComponentBuilder content: () -> Content) {
        self.init(
            label: HTMLBuilder.buildExpression(EmptyHTML()),
            showsLabel: false,
            attributes: [],
            content: HTMLBuilder.buildExpression(content())
        )
    }

    init<Content: Component>(
        _ title: String,
        @ComponentBuilder content: () -> Content
    ) {
        self.init(
            label: HTMLBuilder.buildExpression(Text(title).as(.h3)),
            showsLabel: true,
            attributes: [],
            content: HTMLBuilder.buildExpression(content())
        )
    }
}
