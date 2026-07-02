import SwiftWebUITheme
import SwiftHTML

/// Internal model of how a component negotiates size along one axis, mirroring
/// the intent behind UIKit/SwiftUI Auto Layout `contentHuggingPriority` and
/// `contentCompressionResistancePriority`.
///
/// SwiftUI/Auto Layout resolve sizing with a global constraint solver. Static
/// server-side rendering has no solver, so the negotiation is expressed locally
/// through CSS flexbox using parent-axis-aware class markers. The mapping is:
///
/// - `.hug`  — high hugging priority: the element keeps its intrinsic size and
///   resists being stretched. This is the default (no marker class emitted).
/// - `.fill` — low hugging priority: the element greedily expands to fill the
///   available space on the given axis. Emits a `fill` marker class.
    /// - `.fixed` — a required size constraint. Emits a `hug` marker class plus a
    ///   length declaration so the element neither grows nor shrinks.
enum AxisSizing: Sendable, Equatable {
    case hug
    case fill
    case fixed(String)
}

/// CSS class tokens that encode sizing intent. The stylesheet keys layout rules
/// off these tokens combined with the parent container class, so the same
/// marker resolves to `align-self: stretch` under a column parent and
/// `flex: 1 1 0%` under a row parent — exactly as a cross/main axis would in
/// Auto Layout.
enum LayoutClass {
    /// Greedy on the horizontal axis (low horizontal hugging priority).
    static let fillHorizontal = "swui-fill-h"
    /// Greedy on the vertical axis (low vertical hugging priority).
    static let fillVertical = "swui-fill-v"
    /// Pinned to intrinsic width; blocks upward fill propagation.
    static let hugHorizontal = "swui-hug-h"
    /// Pinned to intrinsic height; blocks upward fill propagation.
    static let hugVertical = "swui-hug-v"
}
