import SwiftHTML

public extension WebUIAttributeMutableHTML {
    func navigationTitle(_ title: String) -> AttributeAppliedContent<Self> {
        applyingAttributes([
            HTMLAttribute("data-navigation-title", title),
        ])
    }
}

public extension HTML {
    func navigationTitle(_ title: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            HTMLAttribute("data-navigation-title", title),
        ]))
    }
}
