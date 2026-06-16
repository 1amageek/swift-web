public struct SemanticShapeStyle: WebShapeStyle, Sendable, Equatable {
    public enum Token: Sendable, Equatable {
        case primary
        case secondary
        case accent
        case accentText
        case danger
        case dangerText
        case background
        case surface
        case surfaceRaised
        case border
    }

    public let token: Token

    public init(_ token: Token) {
        self.token = token
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        let value = switch token {
        case .primary:
            "var(--swui-text)"
        case .secondary:
            "var(--swui-text-muted)"
        case .accent:
            "var(--swui-accent)"
        case .accentText:
            "var(--swui-accent-text)"
        case .danger:
            "var(--swui-danger)"
        case .dangerText:
            "var(--swui-danger-text)"
        case .background:
            "var(--swui-background)"
        case .surface:
            "var(--swui-surface)"
        case .surfaceRaised:
            "var(--swui-surface-raised)"
        case .border:
            "var(--swui-border)"
        }
        return ResolvedStyle(cssValue: value)
    }
}

public extension WebShapeStyle where Self == SemanticShapeStyle {
    static var primary: SemanticShapeStyle { SemanticShapeStyle(.primary) }
    static var secondary: SemanticShapeStyle { SemanticShapeStyle(.secondary) }
    static var accent: SemanticShapeStyle { SemanticShapeStyle(.accent) }
    static var accentText: SemanticShapeStyle { SemanticShapeStyle(.accentText) }
    static var danger: SemanticShapeStyle { SemanticShapeStyle(.danger) }
    static var dangerText: SemanticShapeStyle { SemanticShapeStyle(.dangerText) }
    static var background: SemanticShapeStyle { SemanticShapeStyle(.background) }
    static var surface: SemanticShapeStyle { SemanticShapeStyle(.surface) }
    static var surfaceRaised: SemanticShapeStyle { SemanticShapeStyle(.surfaceRaised) }
    static var border: SemanticShapeStyle { SemanticShapeStyle(.border) }
}
