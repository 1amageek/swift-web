import SwiftHTML

public enum ContentMode: Sendable, Equatable {
    case fit
    case fill

    var objectFitValue: String {
        switch self {
        case .fit:
            "contain"
        case .fill:
            "cover"
        }
    }
}

public extension HTML {
    func aspectRatio(
        _ aspectRatio: Double? = nil,
        contentMode: ContentMode
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        var style = Style.objectFit(contentMode.objectFitValue)
        if let aspectRatio {
            style.append(.aspectRatio(trimmedNumber(aspectRatio)))
        }
        return modifier(HTMLAttributeModifier([styleAttribute(style)]))
    }

    func aspectRatio(
        width: Double,
        height: Double,
        contentMode: ContentMode
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        aspectRatio(width / height, contentMode: contentMode)
    }

    func scaledToFit() -> ModifiedContent<Self, HTMLAttributeModifier> {
        aspectRatio(contentMode: .fit)
    }

    func scaledToFill() -> ModifiedContent<Self, HTMLAttributeModifier> {
        aspectRatio(contentMode: .fill)
    }

    func offset(
        x: WebUILength = 0,
        y: WebUILength = 0
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.transform("translate(\(x.cssValue), \(y.cssValue))"))
        ]))
    }

    func offset(_ offset: CGSize) -> ModifiedContent<Self, HTMLAttributeModifier> {
        self.offset(x: offset.width, y: offset.height)
    }

    func position(_ position: CGPoint) -> ModifiedContent<Self, HTMLAttributeModifier> {
        self.position(x: position.x, y: position.y)
    }

    func position(
        x: WebUILength = 0,
        y: WebUILength = 0
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(Style {
                .position("absolute")
                .left(x.cssValue)
                .top(y.cssValue)
                .transform("translate(-50%, -50%)")
            })
        ]))
    }

    func zIndex(_ value: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.zIndex(trimmedNumber(value)))]))
    }

    func containerRelativeFrame(
        _ axes: Axis.Set,
        alignment: Alignment = .center
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        var style = Style()
        if axes.contains(.horizontal) {
            style.append(.width("100%"))
        }
        if axes.contains(.vertical) {
            style.append(.height("100%"))
        }
        style.append(.justifySelf(alignment.horizontal.cssSelfAlignment))
        style.append(.alignSelf(alignment.vertical.cssSelfAlignment))
        return modifier(HTMLAttributeModifier([styleAttribute(style)]))
    }

    func containerRelativeFrame(
        _ axes: Axis.Set,
        count: Int,
        span: Int = 1,
        spacing: WebUILength,
        alignment: Alignment = .center
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        let denominator = max(count, 1)
        let numerator = min(max(span, 1), denominator)
        let gaps = max(denominator - 1, 0)
        let occupiedGaps = max(numerator - 1, 0)
        let available = "calc((100% - \(gaps) * \(spacing.cssValue)) / \(denominator))"
        let length = "calc(\(available) * \(numerator) + \(occupiedGaps) * \(spacing.cssValue))"
        var style = Style()
        if axes.contains(.horizontal) {
            style.append(.width(length))
        }
        if axes.contains(.vertical) {
            style.append(.height(length))
        }
        style.append(.justifySelf(alignment.horizontal.cssSelfAlignment))
        style.append(.alignSelf(alignment.vertical.cssSelfAlignment))
        return modifier(HTMLAttributeModifier([styleAttribute(style)]))
    }

    func alignmentGuide(
        _ guide: HorizontalAlignment,
        computeValue: @escaping (ViewDimensions) -> WebUILength
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        let value = computeValue(ViewDimensions())
        return modifier(HTMLAttributeModifier([
            .data("alignment-guide-horizontal", guide.cssName),
            styleAttribute(.custom("--swui-alignment-guide-horizontal", value.cssValue)),
        ], role: .semantic))
    }

    func alignmentGuide(
        _ guide: VerticalAlignment,
        computeValue: @escaping (ViewDimensions) -> WebUILength
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        let value = computeValue(ViewDimensions())
        return modifier(HTMLAttributeModifier([
            .data("alignment-guide-vertical", guide.cssName),
            styleAttribute(.custom("--swui-alignment-guide-vertical", value.cssValue)),
        ], role: .semantic))
    }
}

public struct ViewDimensions: Sendable {
    public subscript(_ guide: HorizontalAlignment) -> WebUILength {
        .css("0px")
    }

    public subscript(_ guide: VerticalAlignment) -> WebUILength {
        .css("0px")
    }
}

extension HorizontalAlignment {
    var cssSelfAlignment: String {
        switch self {
        case .leading:
            "start"
        case .center:
            "center"
        case .trailing:
            "end"
        case .stretch:
            "stretch"
        }
    }

    var cssName: String {
        switch self {
        case .leading:
            "leading"
        case .center:
            "center"
        case .trailing:
            "trailing"
        case .stretch:
            "stretch"
        }
    }
}

extension VerticalAlignment {
    var cssSelfAlignment: String {
        switch self {
        case .top:
            "start"
        case .center:
            "center"
        case .bottom:
            "end"
        case .stretch:
            "stretch"
        }
    }

    var cssName: String {
        switch self {
        case .top:
            "top"
        case .center:
            "center"
        case .bottom:
            "bottom"
        case .stretch:
            "stretch"
        }
    }
}
