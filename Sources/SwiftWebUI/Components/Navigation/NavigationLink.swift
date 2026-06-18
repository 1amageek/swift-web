import SwiftHTML

public struct NavigationLink<Label: HTML>: WebUIAttributeComponent {
    private let href: String
    private let attributes: [HTMLAttribute]
    private let label: Label

    public init(
        href: String,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.href = href
        self.attributes = attributes
        self.label = label()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "a",
            attributes: mergedAttributes(
                class: "swui-navigation-link",
                extra: [
                    .href(href),
                    HTMLAttribute("data-navigation-link", "true"),
                ] + attributes
            )
        ) {
            label
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(href: href, attributes: self.attributes + attributes, label: label)
    }

    private init(href: String, attributes: [HTMLAttribute], label: Label) {
        self.href = href
        self.attributes = attributes
        self.label = label
    }
}

public extension NavigationLink where Label == text {
    init(_ title: String, href: String, _ attributes: HTMLAttribute...) {
        self.init(href: href, attributes: attributes, label: text(title))
    }
}
