import SwiftHTML

public struct Toolbar<Content: HTML>: WebUIAttributeComponent {
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(_ attributes: HTMLAttribute..., @HTMLBuilder content: () -> Content) {
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-toolbar \(LayoutClass.fillHorizontal)",
                styles: .gap(Space.small.rawValue),
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(attributes: self.attributes + attributes, content: content)
    }

    private init(attributes: [HTMLAttribute], content: Content) {
        self.attributes = attributes
        self.content = content
    }
}
