import SwiftWebUITheme
import SwiftHTML

public struct Section<Parent: Component, Content: Component, Footer: Component>: AttributeComponent {
    private let header: Parent
    private let footer: Footer
    private let showsHeader: Bool
    private let showsFooter: Bool
    private let attributes: [HTMLAttribute]
    private let childContent: Content

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
        self.childContent = content()
    }

    @ComponentBuilder
    public var content: some Component {
        Element("section", attributes: mergedAttributes(class: "swui-section \(LayoutClass.fillHorizontal)", extra: attributes)) {
            if showsHeader {
                Element("div", attributes: [.class("swui-section-header")]) {
                    header
                }
            }
            childContent
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
            content: childContent
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
        self.childContent = content
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
        self.init(
            header: Text(title).as(.h3),
            footer: EmptyHTML(),
            showsHeader: true,
            showsFooter: false,
            attributes: [],
            content: content()
        )
    }
}

public extension Section where Parent == Text, Footer == Text {
    init(
        _ title: String,
        footer: String,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(
            header: Text(title).as(.h3),
            footer: Text(footer),
            showsHeader: true,
            showsFooter: true,
            attributes: [],
            content: content()
        )
    }
}
