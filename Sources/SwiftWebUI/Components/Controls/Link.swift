import SwiftHTML

public struct Link: WebUIAttributeComponent {
    private let text: String
    private let href: String
    private let attributes: [HTMLAttribute]

    public init(
        _ text: String,
        href: String,
        _ attributes: HTMLAttribute...
    ) {
        self.text = text
        self.href = href
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "a",
            attributes: mergedAttributes(
                class: "swui-link",
                extra: [.href(href)] + attributes
            )
        ) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, href: href, attributes: self.attributes + attributes)
    }

    private init(_ text: String, href: String, attributes: [HTMLAttribute]) {
        self.text = text
        self.href = href
        self.attributes = attributes
    }
}
