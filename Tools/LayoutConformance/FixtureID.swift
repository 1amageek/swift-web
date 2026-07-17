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
