import SwiftWebUITheme
import SwiftHTML

public struct PickerStyleModifier: ComponentModifier {
    private let style: PickerStyleKind

    init(_ style: PickerStyleKind) {
        self.style = style
    }

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
        content.transformEnvironment({ $0.pickerStyle = style })
    }
}

public extension Component {
    func pickerStyle(_ style: PickerStyleKind) -> ModifiedContent {
        modifier(PickerStyleModifier(style))
    }
}
