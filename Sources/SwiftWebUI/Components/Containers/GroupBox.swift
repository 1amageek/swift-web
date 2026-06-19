import SwiftHTML

public struct GroupBox<Content: HTML>: WebUIAttributeComponent {
    private let title: String?
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        @HTMLBuilder content: () -> Content
    ) {
        self.title = nil
        self.attributes = []
        self.content = content()
    }

    public init(
        _ title: String,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
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
            if let title {
                Heading(title, level: .subsection)
                    .class("swui-group-box-title")
            }
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, attributes: self.attributes + attributes, content: content)
    }

    private init(title: String?, attributes: [HTMLAttribute], content: Content) {
        self.title = title
        self.attributes = attributes
        self.content = content
    }
}
