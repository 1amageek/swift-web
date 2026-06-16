import SwiftHTML

public extension HTML {
    func accessibilityLabel(_ label: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.aria("label", label)]))
    }

    func accessibilityHint(_ hint: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.aria("description", hint)]))
    }

    func accessibilityValue(_ value: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.aria("valuetext", value)]))
    }

    func accessibilityHidden(_ hidden: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.aria("hidden", hidden ? "true" : "false")]))
    }

    func accessibilityRole(_ role: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([.role(role)]))
    }
}

public extension WebUIAttributeMutableHTML {
    func accessibilityLabel(_ label: String) -> Self {
        addingAttributes([.aria("label", label)])
    }

    func accessibilityHint(_ hint: String) -> Self {
        addingAttributes([.aria("description", hint)])
    }

    func accessibilityValue(_ value: String) -> Self {
        addingAttributes([.aria("valuetext", value)])
    }

    func accessibilityHidden(_ hidden: Bool = true) -> Self {
        addingAttributes([.aria("hidden", hidden ? "true" : "false")])
    }

    func accessibilityRole(_ role: String) -> Self {
        addingAttributes([.role(role)])
    }
}
