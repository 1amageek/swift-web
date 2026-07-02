import SwiftWebUITheme
import SwiftHTML

public struct GridItem: Sendable, Equatable {
    public enum Size: Sendable, Equatable {
        case fixed(Double)
        case flexible(minimum: Double = 10, maximum: Double = .infinity)
        case adaptive(minimum: Double, maximum: Double = .infinity)
    }

    public var size: Size

    /// The spacing to the next item, mirroring SwiftUI's `GridItem.spacing`.
    ///
    /// Web contract: CSS Grid has no per-track gap, so a per-item spacing is
    /// not supported on the web and this value is not lowered into CSS. Use
    /// the grid's `spacing:` parameter for the (uniform) gap between tracks.
    public var spacing: Double?

    /// The alignment of views within this item's track, mirroring SwiftUI's
    /// `GridItem.alignment`.
    ///
    /// Web contract: CSS Grid cannot align a single track independently, so
    /// the alignment is lowered onto the grid container (`justify-items` +
    /// `align-items`, overriding the grid's own `alignment:` parameter, as in
    /// SwiftUI) only when every item requests the same alignment. Mixed
    /// per-track alignments are not supported on the web and are not lowered.
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

/// The container-level lowering of `GridItem.alignment`: the shared alignment
/// when every item requests the same one, or `nil` when items disagree or do
/// not specify an alignment (see the `GridItem.alignment` web contract).
func uniformGridItemAlignment(_ items: [GridItem]) -> Alignment? {
    guard let first = items.first, let alignment = first.alignment else {
        return nil
    }
    guard items.allSatisfy({ $0.alignment == alignment }) else {
        return nil
    }
    return alignment
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
