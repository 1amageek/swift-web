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
