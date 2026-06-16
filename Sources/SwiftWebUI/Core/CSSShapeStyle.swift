public struct CSSShapeStyle: WebShapeStyle, Sendable, Equatable, ExpressibleByStringLiteral {
    public let value: String

    public init(_ value: String) {
        self.value = value
    }

    public init(stringLiteral value: String) {
        self.value = value
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        ResolvedStyle(cssValue: value)
    }
}

public extension WebShapeStyle where Self == CSSShapeStyle {
    static func css(_ value: String) -> CSSShapeStyle {
        CSSShapeStyle(value)
    }
}
