import SwiftWebUITheme
import SwiftHTML

@available(*, deprecated, message: "Every direct child of List is a row, matching SwiftUI; use List(_:rowContent:) for data-driven rows")
public struct ListRow<Content: HTML>: WebUIAttributeComponent {
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
                class: "swui-list-row",
                extra: [.role("listitem")] + attributes
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
