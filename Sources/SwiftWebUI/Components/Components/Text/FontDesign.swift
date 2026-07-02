import SwiftWebUITheme
public extension Font {
    enum Design: Sendable, Equatable {
        case `default`
        case serif
        case rounded
        case monospaced

        var cssValue: String {
            switch self {
            case .default:
                "var(--swui-font-family)"
            case .serif:
                "ui-serif, Georgia, Cambria, \"Times New Roman\", Times, serif"
            case .rounded:
                "\"SF Pro Rounded\", var(--swui-font-family)"
            case .monospaced:
                "var(--swui-mono-font-family)"
            }
        }
    }
}
