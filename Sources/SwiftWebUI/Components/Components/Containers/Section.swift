import SwiftWebUITheme
import SwiftHTML

public struct Section<Parent: HTML, Content: HTML, Footer: HTML>: WebUIAttributeComponent {
    private let header: Parent
    private let footer: Footer
    private let showsHeader: Bool
    private let showsFooter: Bool
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder header: () -> Parent,
        @HTMLBuilder footer: () -> Footer
    ) {
        self.header = header()
        self.footer = footer()
        self.showsHeader = true
        self.showsFooter = true
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("section", attributes: mergedAttributes(class: "swui-section \(LayoutClass.fillHorizontal)", extra: attributes)) {
            if showsHeader {
                Element("div", attributes: [.class("swui-section-header")]) {
                    header
                }
            }
            content
            if showsFooter {
                Element("div", attributes: [.class("swui-section-footer")]) {
                    footer
                }
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            header: header,
            footer: footer,
            showsHeader: showsHeader,
            showsFooter: showsFooter,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        header: Parent,
        footer: Footer,
        showsHeader: Bool,
        showsFooter: Bool,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.header = header
        self.footer = footer
        self.showsHeader = showsHeader
        self.showsFooter = showsFooter
        self.attributes = attributes
        self.content = content
    }
}

public extension Section where Parent == EmptyHTML, Footer == EmptyHTML {
    init(@HTMLBuilder content: () -> Content) {
        self.init(
            header: EmptyHTML(),
            footer: EmptyHTML(),
            showsHeader: false,
            showsFooter: false,
            attributes: [],
            content: content()
        )
    }
}

public extension Section where Footer == EmptyHTML {
    init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder header: () -> Parent
    ) {
        self.init(
            header: header(),
            footer: EmptyHTML(),
            showsHeader: true,
            showsFooter: false,
            attributes: [],
            content: content()
        )
    }
}

public extension Section where Parent == EmptyHTML {
    init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder footer: () -> Footer
    ) {
        self.init(
            header: EmptyHTML(),
            footer: footer(),
            showsHeader: false,
            showsFooter: true,
            attributes: [],
            content: content()
        )
    }
}

public extension Section where Parent == Text, Footer == EmptyHTML {
    init(_ title: String, @HTMLBuilder content: () -> Content) {
        self.init(content: content) {
            Text(title, as: .h3)
        }
    }
}

public extension Section where Parent == Text, Footer == Text {
    init(
        _ title: String,
        footer: String,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(content: content) {
            Text(title, as: .h3)
        } footer: {
            Text(footer)
        }
    }
}
