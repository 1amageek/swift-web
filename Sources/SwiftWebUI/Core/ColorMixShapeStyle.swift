public struct ColorMixShapeStyle: WebShapeStyle {
    public enum ColorSpace: String, Sendable {
        case srgb
        case displayP3 = "display-p3"
    }

    private let colorSpace: ColorSpace
    private let first: AnyWebShapeStyle
    private let firstPercentage: Double
    private let second: AnyWebShapeStyle

    public init<First: WebShapeStyle, Second: WebShapeStyle>(
        in colorSpace: ColorSpace = .srgb,
        _ first: First,
        _ firstPercentage: Double,
        _ second: Second
    ) {
        self.colorSpace = colorSpace
        self.first = AnyWebShapeStyle(first)
        self.firstPercentage = firstPercentage
        self.second = AnyWebShapeStyle(second)
    }

    public func resolve(in context: StyleResolutionContext) -> ResolvedStyle {
        let firstValue = first.resolve(in: context).cssValue
        let secondValue = second.resolve(in: context).cssValue
        return ResolvedStyle(
            cssValue: "color-mix(in \(colorSpace.rawValue), \(firstValue) \(trimmedNumber(firstPercentage))%, \(secondValue))"
        )
    }
}

public extension WebShapeStyle where Self == ColorMixShapeStyle {
    static func mix(
        _ first: SemanticShapeStyle,
        _ firstPercentage: Double,
        _ second: SemanticShapeStyle,
        in colorSpace: ColorMixShapeStyle.ColorSpace = .srgb
    ) -> ColorMixShapeStyle {
        ColorMixShapeStyle(in: colorSpace, first, firstPercentage, second)
    }

    static func mix(
        _ first: SemanticShapeStyle,
        _ firstPercentage: Double,
        _ second: CSSShapeStyle,
        in colorSpace: ColorMixShapeStyle.ColorSpace = .srgb
    ) -> ColorMixShapeStyle {
        ColorMixShapeStyle(in: colorSpace, first, firstPercentage, second)
    }

    static func mix(
        _ first: CSSShapeStyle,
        _ firstPercentage: Double,
        _ second: SemanticShapeStyle,
        in colorSpace: ColorMixShapeStyle.ColorSpace = .srgb
    ) -> ColorMixShapeStyle {
        ColorMixShapeStyle(in: colorSpace, first, firstPercentage, second)
    }

    static func mix(
        _ first: CSSShapeStyle,
        _ firstPercentage: Double,
        _ second: CSSShapeStyle,
        in colorSpace: ColorMixShapeStyle.ColorSpace = .srgb
    ) -> ColorMixShapeStyle {
        ColorMixShapeStyle(in: colorSpace, first, firstPercentage, second)
    }
}
