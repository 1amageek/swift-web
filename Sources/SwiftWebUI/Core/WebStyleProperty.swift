import SwiftHTML

public enum WebStyleProperty: Sendable, Equatable {
    case foreground
    case background
    case tint
    case border(width: WebUILength)

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
        case .tint:
            return Style {
                .custom("--swui-tint", resolvedStyle.cssValue)
                .accentColor(resolvedStyle.cssValue)
            }
        case .border(let width):
            return .border("\(width.cssValue) solid \(resolvedStyle.cssValue)")
        }
    }
}

extension WebUILength {
    var cssValue: String {
        switch self {
        case .css(let value):
            value
        case .infinity:
            "100%"
        }
    }
}
