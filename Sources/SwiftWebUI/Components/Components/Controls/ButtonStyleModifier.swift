import SwiftWebUITheme
import SwiftHTML

public struct ButtonStyleModifier: ComponentModifier {
    private let style: ButtonStyleKind

    init(_ style: ButtonStyleKind) {
        self.style = style
    }

    @ComponentBuilder
    public func content(_ content: ModifierContent) -> some Component {
        content.transformEnvironment({ $0.buttonStyle = style })
    }
}

public extension Component {
    func buttonStyle(_ style: ButtonStyleKind) -> ModifiedContent {
        modifier(ButtonStyleModifier(style))
    }
}
