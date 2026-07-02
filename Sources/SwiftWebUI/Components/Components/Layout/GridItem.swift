import SwiftWebUITheme
import SwiftHTML

public struct GridItem: Sendable, Equatable {
    public enum Size: Sendable, Equatable {
        case fixed(Double)
        case flexible(minimum: Double = 10, maximum: Double = .infinity)
        case adaptive(minimum: Double, maximum: Double = .infinity)
    }

    public var size: Size
    public var spacing: Double?
    public var alignment: Alignment?

    public init(
        _ size: Size = .flexible(),
        spacing: Double? = nil,
        alignment: Alignment? = nil
    ) {
        self.size = size
        self.spacing = spacing
        self.alignment = alignment
    }
}

func gridTemplateTracks(_ items: [GridItem]) -> String {
    guard !items.isEmpty else {
        return "1fr"
    }

    return items
        .map { gridTemplateTrack($0.size) }
        .joined(separator: " ")
}

private func gridTemplateTrack(_ size: GridItem.Size) -> String {
    switch size {
    case .fixed(let value):
        cssTrackLength(value, infinityValue: "1fr")
    case .flexible(let minimum, let maximum):
        "minmax(\(cssTrackLength(minimum, infinityValue: "0")), \(cssTrackLength(maximum, infinityValue: "1fr")))"
    case .adaptive(let minimum, let maximum):
        "repeat(auto-fit, minmax(\(cssTrackLength(minimum, infinityValue: "0")), \(cssTrackLength(maximum, infinityValue: "1fr"))))"
    }
}

func cssTrackLength(_ value: Double, infinityValue: String) -> String {
    value.isInfinite ? infinityValue : pixelValue(value)
}
