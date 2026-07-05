import SwiftWebUITheme
import SwiftHTML

public struct GroupBox<Label: HTML, Content: HTML>: WebUIAttributeComponent {
    private let label: Label
    private let showsLabel: Bool
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.showsLabel = true
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
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
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(label: label, showsLabel: showsLabel, attributes: self.attributes + attributes, content: content)
    }

    private init(label: Label, showsLabel: Bool, attributes: [HTMLAttribute], content: Content) {
        self.label = label
        self.showsLabel = showsLabel
        self.attributes = attributes
        self.content = content
    }
}

public extension GroupBox where Label == EmptyHTML {
    init(@HTMLBuilder content: () -> Content) {
        self.init(label: EmptyHTML(), showsLabel: false, attributes: [], content: content())
    }
}

public extension GroupBox where Label == Text {
    init(
        _ title: String,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(content: content) {
            Text(title).as(.h3)
        }
    }
}
