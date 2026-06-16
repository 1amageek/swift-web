import SwiftHTML

public struct Card<Content: HTML>: WebUIAttributeComponent {
    private let padding: Space
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        padding: Space = .large,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.padding = padding
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-card",
                styles: .padding(padding.rawValue),
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(padding: padding, attributes: self.attributes + attributes, content: content)
    }

    private init(padding: Space, attributes: [HTMLAttribute], content: Content) {
        self.padding = padding
        self.attributes = attributes
        self.content = content
    }
}
