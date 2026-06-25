import SwiftHTML
import SwiftWebStyle

public struct List<Content: HTML>: WebUIAttributeComponent {
    private let attributes: [HTMLAttribute]
    private let content: Content
    @Environment(\.listStyle) private var listStyle: ListStyleKind

    public init(
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName(
                    "swui-list",
                    listStyle.className,
                    LayoutClass.fillHorizontal,
                    Space.small.gapClassName.rawValue
                ),
                extra: [.role("list")] + attributes
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
