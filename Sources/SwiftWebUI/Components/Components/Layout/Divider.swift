import SwiftWebUITheme
import SwiftHTML

public struct Divider: AttributeComponent {
    private let attributes: [HTMLAttribute]

    public init() {
        self.attributes = []
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-divider",
                extra: [.role("separator")] + attributes
            )
        )
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(attributes: self.attributes + attributes)
    }

    private init(attributes: [HTMLAttribute]) {
        self.attributes = attributes
    }
}
