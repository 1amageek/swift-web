import SwiftWebUITheme
import SwiftHTML

public extension Component {
    func navigationTitle(_ title: String) -> ModifiedContent {
        modifier(HTMLAttributeModifier([
            HTMLAttribute("data-navigation-title", title),
        ], role: .semantic))
    }
}
