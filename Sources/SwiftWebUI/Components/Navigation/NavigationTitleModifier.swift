import SwiftWebUITheme
import SwiftHTML

public extension HTML {
    func navigationTitle(_ title: String) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            HTMLAttribute("data-navigation-title", title),
        ], role: .semantic))
    }
}
