import SwiftHTML

public struct Font: Sendable {
    let style: Style

    public init(
        size: Length,
        lineHeight: String? = nil,
        weight: FontWeight? = nil,
        design: FontDesign = .default
    ) {
        var style = Style {
            .fontSize(size.cssValue)
            .fontFamily(design.cssValue)
        }
        if let lineHeight {
            style.append(.lineHeight(lineHeight))
        }
        if let weight {
            style.append(.fontWeight(weight.cssValue))
        }
        self.style = style
    }

    init(style: Style) {
        self.style = style
    }

    public static let largeTitle = Font(size: .rem(3), lineHeight: "1.05", weight: .bold)
    public static let title = Font(size: .rem(2), lineHeight: "1.15", weight: .semibold)
    public static let title2 = Font(size: .rem(1.5), lineHeight: "1.2", weight: .semibold)
    public static let title3 = Font(size: .rem(1.25), lineHeight: "1.25", weight: .semibold)
    public static let headline = Font(size: .rem(1), lineHeight: "1.35", weight: .semibold)
    public static let body = Font(size: .custom("var(--swui-base-size)"), lineHeight: "var(--swui-line-height)")
    public static let callout = Font(size: .rem(0.9375), lineHeight: "1.45")
    public static let subheadline = Font(size: .rem(0.875), lineHeight: "1.4")
    public static let footnote = Font(size: .rem(0.8125), lineHeight: "1.35")
    public static let caption = Font(size: .rem(0.75), lineHeight: "1.3")
}
