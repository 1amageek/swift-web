import SwiftHTML

public enum WebStyleProperty: Sendable, Equatable {
    case foreground
    case background
    case overlay
    case border(width: Length)

    func style(for resolvedStyle: ResolvedStyle) -> Style {
        if !resolvedStyle.style.isEmpty {
            return resolvedStyle.style
        }

        // A class-driven shape style (e.g. `Material`) carries its recipe in
        // class tokens and resolves to an empty cssValue. Emitting an inline
        // `background: ;` here would be invalid and would shadow the class rule,
        // so contribute no inline declaration in that case.
        if resolvedStyle.cssValue.isEmpty {
            return Style()
        }

        switch self {
        case .foreground:
            return .color(resolvedStyle.cssValue)
        case .background:
            return .background(resolvedStyle.cssValue)
        case .overlay:
            return .boxShadow("inset 0 0 0 9999px \(resolvedStyle.cssValue)")
        case .border(let width):
            return .border("\(width.cssValue) solid \(resolvedStyle.cssValue)")
        }
    }

    var modifierRole: HTMLModifierRole {
        switch self {
        case .foreground:
            .textStyle
        case .background, .overlay, .border:
            .box
        }
    }

    var modifierClassName: String {
        switch self {
        case .foreground:
            "swui-style-foreground"
        case .background:
            "swui-style-background"
        case .overlay:
            "swui-style-overlay"
        case .border:
            "swui-style-border"
        }
    }
}
