import SwiftHTML

public struct GridItem: Sendable, Equatable {
    public enum Size: Sendable, Equatable {
        case fixed(Length)
        case flexible(minimum: Length = 10, maximum: Length = .infinity)
        case adaptive(minimum: Length, maximum: Length = .infinity)
    }

    public var size: Size
    public var spacing: Space?
    public var alignment: Alignment?

    public init(
        _ size: Size = .flexible(),
        spacing: Space? = nil,
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
    case .fixed(let length):
        cssLength(length, infinityValue: "1fr")
    case .flexible(let minimum, let maximum):
        "minmax(\(cssLength(minimum, infinityValue: "0")), \(cssLength(maximum, infinityValue: "1fr")))"
    case .adaptive(let minimum, let maximum):
        "repeat(auto-fit, minmax(\(cssLength(minimum, infinityValue: "0")), \(cssLength(maximum, infinityValue: "1fr"))))"
    }
}

func cssLength(_ length: Length, infinityValue: String) -> String {
    switch length {
    case .infinity:
        infinityValue
    default:
        length.cssValue
    }
}
