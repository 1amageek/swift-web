import SwiftHTML

public struct Section<Content: HTML>: WebUIAttributeComponent {
    private let title: String?
    private let footer: String?
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        _ title: String? = nil,
        footer: String? = nil,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
        self.footer = footer
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("section", attributes: mergedAttributes(class: "swui-section \(LayoutClass.fillHorizontal)", extra: attributes)) {
            if let title {
                Heading(title, level: .subsection)
            }
            content
            if let footer {
                Text(footer, tone: .muted).class("swui-section-footer")
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title, footer: footer, attributes: self.attributes + attributes, content: content)
    }

    private init(_ title: String?, footer: String?, attributes: [HTMLAttribute], content: Content) {
        self.title = title
        self.footer = footer
        self.attributes = attributes
        self.content = content
    }
}
