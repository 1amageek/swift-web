import SwiftHTML

public struct Font: Sendable {
    let style: Style

    public init(
        size: WebUILength,
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

    public static let largeTitle = Font(size: "3rem", lineHeight: "1.05", weight: .bold)
    public static let title = Font(size: "2rem", lineHeight: "1.15", weight: .semibold)
    public static let title2 = Font(size: "1.5rem", lineHeight: "1.2", weight: .semibold)
    public static let title3 = Font(size: "1.25rem", lineHeight: "1.25", weight: .semibold)
    public static let headline = Font(size: "1rem", lineHeight: "1.35", weight: .semibold)
    public static let body = Font(size: "var(--swui-base-size)", lineHeight: "var(--swui-line-height)")
    public static let callout = Font(size: "0.9375rem", lineHeight: "1.45")
    public static let subheadline = Font(size: "0.875rem", lineHeight: "1.4")
    public static let footnote = Font(size: "0.8125rem", lineHeight: "1.35")
    public static let caption = Font(size: "0.75rem", lineHeight: "1.3")
}
