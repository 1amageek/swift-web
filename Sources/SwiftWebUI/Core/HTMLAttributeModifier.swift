import SwiftHTML

enum HTMLModifierRole: Sendable, Equatable {
    case box
    case textStyle
    case semantic

    var className: String {
        switch self {
        case .box:
            "swui-box-modifier"
        case .textStyle:
            "swui-text-style-modifier"
        case .semantic:
            "swui-semantic-modifier"
        }
    }
}

public struct HTMLAttributeModifier: ComponentModifier {
    private let attributes: [HTMLAttribute]
    private let role: HTMLModifierRole

    init(_ attributes: [HTMLAttribute], role: HTMLModifierRole = .box) {
        self.attributes = attributes
        self.role = role
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-modifier swui-attribute \(role.className)",
                extra: attributes
            )
        ) {
            content
        }
    }
}
