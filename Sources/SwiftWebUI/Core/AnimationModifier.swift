import SwiftHTML

/// Publishes a `--swui-animation` custom property over a subtree. Components read
/// it through `transition: … var(--swui-animation, …)`, so a state change patched
/// by the runtime is interpolated by the browser. The wrapper is `display:
/// contents`, so it adds no box to the layout — it only carries the inherited
/// custom property.
public struct AnimationModifier: ComponentModifier {
    private let animation: Animation?

    init(_ animation: Animation?) {
        self.animation = animation
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        div(.class("swui-animation-scope"), styleAttribute(.custom("--swui-animation", cssValue))) {
            content
        }
    }

    // `nil` disables animation for the subtree (SwiftUI `.animation(nil)`), which
    // lowers to a zero-duration transition that overrides any ancestor value.
    private var cssValue: String {
        animation?.cssValue ?? "0s"
    }
}

public extension HTML {
    /// Applies the given animation to value-driven changes within this subtree.
    ///
    /// The web lowering publishes the animation as the inherited
    /// `--swui-animation` custom property; any animatable property a descendant
    /// changes while it is in scope is interpolated by the browser. `value` is
    /// kept for SwiftUI API parity.
    func animation(
        _ animation: Animation?,
        value: some Equatable
    ) -> ModifiedContent<Self, AnimationModifier> {
        modifier(AnimationModifier(animation))
    }
}
