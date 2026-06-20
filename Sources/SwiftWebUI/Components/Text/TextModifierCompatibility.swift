import SwiftHTML

public extension Text {
    enum Case: Sendable, Equatable {
        case uppercase
        case lowercase

        var cssValue: String {
            switch self {
            case .uppercase:
                "uppercase"
            case .lowercase:
                "lowercase"
            }
        }
    }

    enum TruncationMode: Sendable, Equatable {
        case head
        case middle
        case tail
    }

    enum LineStyle: Sendable, Equatable {
        public enum Pattern: Sendable, Equatable {
            case solid
            case dash
            case dot
            case dashDot
            case dashDotDot

            var cssValue: String {
                switch self {
                case .solid:
                    "solid"
                case .dash:
                    "dashed"
                case .dot:
                    "dotted"
                case .dashDot, .dashDotDot:
                    "dashed"
                }
            }
        }
    }
}

public extension Font {
    enum Width: Sendable, Equatable {
        case compressed
        case condensed
        case standard
        case expanded

        var cssValue: String {
            switch self {
            case .compressed:
                "75%"
            case .condensed:
                "87.5%"
            case .standard:
                "100%"
            case .expanded:
                "112.5%"
            }
        }
    }
}

public enum TextAlignment: Sendable, Equatable {
    case leading
    case center
    case trailing

    var cssValue: String {
        switch self {
        case .leading:
            "left"
        case .center:
            "center"
        case .trailing:
            "right"
        }
    }
}

public enum TextSelection: Sendable, Equatable {
    case enabled
    case disabled

    var cssValue: String {
        switch self {
        case .enabled:
            "text"
        case .disabled:
            "none"
        }
    }
}

public extension HTML {
    func lineLimit(_ number: Int?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let number else {
            return modifier(HTMLAttributeModifier([]))
        }
        return modifier(HTMLAttributeModifier([
            styleAttribute(Style {
                .custom("display", "-webkit-box")
                .custom("-webkit-line-clamp", "\(number)")
                .custom("-webkit-box-orient", "vertical")
                .overflow("hidden")
            })
        ]))
    }

    func multilineTextAlignment(_ alignment: TextAlignment) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.textAlign(alignment.cssValue))], role: .textStyle))
    }

    func lineSpacing(_ lineSpacing: Length) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(Style {
                .custom("--swui-line-spacing", lineSpacing.cssValue)
                .lineHeight("calc(var(--swui-line-height) + \(lineSpacing.cssValue))")
            })
        ], role: .textStyle))
    }

    func truncationMode(_ mode: Text.TruncationMode) -> ModifiedContent<Self, HTMLAttributeModifier> {
        let style: Style
        switch mode {
        case .tail:
            style = Style {
                .overflow("hidden")
                .textOverflow("ellipsis")
                .whiteSpace("nowrap")
            }
        case .head:
            style = Style {
                .overflow("hidden")
                .textOverflow("ellipsis")
                .whiteSpace("nowrap")
                .direction("rtl")
                .textAlign("left")
            }
        case .middle:
            style = Style {
                .overflow("hidden")
                .textOverflow("ellipsis")
                .whiteSpace("nowrap")
            }
        }
        return modifier(HTMLAttributeModifier([styleAttribute(style)], role: .textStyle))
    }

    func allowsTightening(_ flag: Bool) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.fontKerning(flag ? "normal" : "none"))
        ], role: .textStyle))
    }

    func minimumScaleFactor(_ factor: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.custom("--swui-minimum-scale-factor", trimmedNumber(factor)))
        ], role: .textStyle))
    }

    func textCase(_ textCase: Text.Case?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let textCase else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return modifier(HTMLAttributeModifier([
            styleAttribute(.textTransform(textCase.cssValue))
        ], role: .textStyle))
    }

    func fontWidth(_ width: Font.Width?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard let width else {
            return modifier(HTMLAttributeModifier([], role: .textStyle))
        }
        return modifier(HTMLAttributeModifier([
            styleAttribute(.fontStretch(width.cssValue))
        ], role: .textStyle))
    }

    func kerning(_ kerning: Length) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.letterSpacing(kerning.cssValue))
        ], role: .textStyle))
    }

    func tracking(_ tracking: Length) -> ModifiedContent<Self, HTMLAttributeModifier> {
        kerning(tracking)
    }

    func baselineOffset(_ baselineOffset: Length) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.verticalAlign(baselineOffset.cssValue))
        ], role: .textStyle))
    }

    func underline(
        _ isActive: Bool = true,
        pattern: Text.LineStyle.Pattern = .solid,
        color: String? = nil
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        var style = Style.textDecorationLine(isActive ? "underline" : "none")
        if isActive {
            style.append(.textDecorationStyle(pattern.cssValue))
            if let color {
                style.append(.textDecorationColor(color))
            }
        }
        return modifier(HTMLAttributeModifier([
            styleAttribute(style)
        ], role: .textStyle))
    }

    func strikethrough(
        _ isActive: Bool = true,
        pattern: Text.LineStyle.Pattern = .solid,
        color: String? = nil
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        var style = Style.textDecorationLine(isActive ? "line-through" : "none")
        if isActive {
            style.append(.textDecorationStyle(pattern.cssValue))
            if let color {
                style.append(.textDecorationColor(color))
            }
        }
        return modifier(HTMLAttributeModifier([
            styleAttribute(style)
        ], role: .textStyle))
    }

    func textSelection(_ selectability: TextSelection) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.userSelect(selectability.cssValue))
        ], role: .textStyle))
    }
}
