import SwiftWebUITheme
import SwiftHTML

/// A transition for a view's insertion and removal.
///
/// Each transition describes the visual "from" state for insertion (animated to
/// the normal state via CSS `@starting-style`) and the "to" state for removal
/// (animated to before the runtime removes the element). The browser performs
/// the interpolation; there is no Swift-side animation engine.
public struct AnyTransition: Sendable, Equatable {
    var insertionOpacity: Double?
    var insertionTransform: String?
    var removalOpacity: Double?
    var removalTransform: String?
    var transformOrigin: String?
    var transitionAnimation: Animation?

    init(
        insertionOpacity: Double? = nil,
        insertionTransform: String? = nil,
        removalOpacity: Double? = nil,
        removalTransform: String? = nil,
        transformOrigin: String? = nil,
        transitionAnimation: Animation? = nil
    ) {
        self.insertionOpacity = insertionOpacity
        self.insertionTransform = insertionTransform
        self.removalOpacity = removalOpacity
        self.removalTransform = removalTransform
        self.transformOrigin = transformOrigin
        self.transitionAnimation = transitionAnimation
    }

    /// A transition that does not animate (the view appears/disappears instantly).
    public static let identity = AnyTransition()

    /// Whether this transition carries no insertion or removal state, in which
    /// case the view appears and disappears instantly.
    var isIdentity: Bool {
        insertionOpacity == nil && insertionTransform == nil
            && removalOpacity == nil && removalTransform == nil
    }

    /// Fades the view in and out.
    public static let opacity = AnyTransition(insertionOpacity: 0, removalOpacity: 0)

    /// Scales the view from nothing on insertion and down to nothing on removal.
    public static let scale = AnyTransition.scale(0)

    public static func scale(_ scale: Double = 0, anchor: UnitPoint = .center) -> AnyTransition {
        let transform = "scale(\(trimmedNumber(scale)))"
        return AnyTransition(
            insertionTransform: transform,
            removalTransform: transform,
            transformOrigin: anchor == .center ? nil : "\(percent(anchor.x)) \(percent(anchor.y))"
        )
    }

    /// Moves the view in from / out toward the given edge.
    public static func move(edge: Edge) -> AnyTransition {
        let transform: String
        switch edge {
        case .leading: transform = "translateX(-100%)"
        case .trailing: transform = "translateX(100%)"
        case .top: transform = "translateY(-100%)"
        case .bottom: transform = "translateY(100%)"
        }
        return AnyTransition(insertionTransform: transform, removalTransform: transform)
    }

    /// Slides in from the leading edge and out toward the trailing edge.
    public static let slide = AnyTransition.asymmetric(
        insertion: .move(edge: .leading),
        removal: .move(edge: .trailing)
    )

    public static func offset(x: Length = 0, y: Length = 0) -> AnyTransition {
        let transform = "translate(\(x.cssValue), \(y.cssValue))"
        return AnyTransition(insertionTransform: transform, removalTransform: transform)
    }

    public static func offset(_ offset: CGSize) -> AnyTransition {
        Self.offset(x: offset.width, y: offset.height)
    }

    /// A transition with different insertion and removal behavior.
    public static func asymmetric(insertion: AnyTransition, removal: AnyTransition) -> AnyTransition {
        AnyTransition(
            insertionOpacity: insertion.insertionOpacity,
            insertionTransform: insertion.insertionTransform,
            removalOpacity: removal.removalOpacity,
            removalTransform: removal.removalTransform,
            transformOrigin: insertion.transformOrigin ?? removal.transformOrigin,
            transitionAnimation: insertion.transitionAnimation ?? removal.transitionAnimation
        )
    }

    /// Combines this transition with another (e.g. `.opacity.combined(with: .scale)`).
    public func combined(with other: AnyTransition) -> AnyTransition {
        AnyTransition(
            insertionOpacity: insertionOpacity ?? other.insertionOpacity,
            insertionTransform: Self.combineTransforms(insertionTransform, other.insertionTransform),
            removalOpacity: removalOpacity ?? other.removalOpacity,
            removalTransform: Self.combineTransforms(removalTransform, other.removalTransform),
            transformOrigin: transformOrigin ?? other.transformOrigin,
            transitionAnimation: transitionAnimation ?? other.transitionAnimation
        )
    }

    /// Associates an animation with this transition.
    public func animation(_ animation: Animation?) -> AnyTransition {
        var copy = self
        copy.transitionAnimation = animation
        return copy
    }

    private static func combineTransforms(_ first: String?, _ second: String?) -> String? {
        switch (first, second) {
        case (let first?, let second?): "\(first) \(second)"
        case (let first?, nil): first
        case (nil, let second?): second
        case (nil, nil): nil
        }
    }

    private static func percent(_ value: Double) -> String {
        "\(trimmedNumber(value * 100))%"
    }
}
