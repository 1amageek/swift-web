import SwiftWebUITheme
import SwiftHTML

public struct PickerStyleModifier: ComponentModifier {
    private let style: PickerStyleKind

    init(_ style: PickerStyleKind) {
        self.style = style
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.transformEnvironment({ $0.pickerStyle = style })
    }
}

public extension HTML {
    func pickerStyle(_ style: PickerStyleKind) -> ModifiedContent<Self, PickerStyleModifier> {
        modifier(PickerStyleModifier(style))
    }
}
