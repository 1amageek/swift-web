import SwiftHTML

public struct ButtonStyleModifier: ComponentModifier {
    private let style: ButtonStyleKind

    init(_ style: ButtonStyleKind) {
        self.style = style
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.environment(ButtonStyleEnvironmentKey.self, style)
    }
}

public extension HTML {
    func buttonStyle(_ style: ButtonStyleKind) -> ModifiedContent<Self, ButtonStyleModifier> {
        modifier(ButtonStyleModifier(style))
    }
}
