#if os(macOS)
/// The fixture set is derived from the known hard cases of lowering
/// SwiftUI layout onto CSS: spacers, frame fill/bounds, and nested stacks.
/// Every fixture is defined twice — once in SwiftUI (the oracle) and once
/// in SwiftWebUI (the system under test) — and both are laid out inside a
/// 400x300 top-leading container.
enum FixtureID: String, CaseIterable {
    case hstackSpacer = "hstack-spacer"
    case hstackTwoSpacers = "hstack-two-spacers"
    case vstackSpacer = "vstack-spacer"
    case spacerMinLength = "spacer-min-length"
    case fillInVStack = "fill-in-vstack"
    case fillInHStack = "fill-in-hstack"
    case boundedMaxCenter = "bounded-max-center"
    case fixedFrame = "fixed-frame"
    case nestedOverflow = "nested-overflow"
    case nestedStacksSpacers = "nested-stacks-spacers"
    case vstackAlignLeading = "vstack-align-leading"
    case vstackAlignTrailing = "vstack-align-trailing"
    case hstackAlignTop = "hstack-align-top"
    case hstackAlignBottom = "hstack-align-bottom"
    case frameAlignTopLeading = "frame-align-top-leading"
    case frameAlignBottomTrailing = "frame-align-bottom-trailing"
    case vstackSpacing = "vstack-spacing"
    case hstackSpacing = "hstack-spacing"
    case paddingUniform = "padding-uniform"
    case zstackCenter = "zstack-center"
    case zstackBottomTrailing = "zstack-bottom-trailing"
    case minWidthFrame = "min-width-frame"
    case spacersCenterV = "spacers-center-v"
    case spacersCenterH = "spacers-center-h"
    case gridRows = "grid-rows"
    case lazyVGridFixed = "lazy-vgrid-fixed"
    case scrollViewClip = "scroll-view-clip"
}

/// Shared harness geometry.
enum Harness {
    static let rootWidth: Double = 400
    static let rootHeight: Double = 300
    static let tolerance: Double = 1.5
}

/// One probed rectangle, relative to the fixture root's top-leading corner.
struct ProbeRect: Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double

    func maxDelta(to other: ProbeRect) -> Double {
        max(
            abs(x - other.x),
            abs(y - other.y),
            abs(width - other.width),
            abs(height - other.height)
        )
    }
}
#endif
