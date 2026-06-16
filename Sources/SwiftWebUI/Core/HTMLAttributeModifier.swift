import SwiftHTML

public struct HTMLAttributeModifier: ComponentModifier {
    private let attributes: [HTMLAttribute]

    init(_ attributes: [HTMLAttribute]) {
        self.attributes = attributes
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        Element(
            "span",
            attributes: mergedAttributes(
                class: "swui-modifier swui-attribute",
                extra: attributes
            )
        ) {
            content
        }
    }
}
