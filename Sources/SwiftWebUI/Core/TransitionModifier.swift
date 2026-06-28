import SwiftWebUITheme
import SwiftHTML

/// Wraps a conditionally-present view so it animates on insertion and removal.
///
/// Insertion is pure CSS: `@starting-style` applies the transition's "from" state
/// to the freshly-inserted `.swui-transition` element, which the browser then
/// animates to the normal state. Removal needs the runtime: the element carries
/// the markers (`data-swui-transition`, `data-swui-exit-ms`) the runtime reads to
/// add `.swui-exiting` and detach the node only after the exit animation.
public struct TransitionModifier: ComponentModifier {
    private let transition: AnyTransition

    init(_ transition: AnyTransition) {
        self.transition = transition
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        if transition.isIdentity {
            content
        } else {
            Element("div", attributes: attributes) {
                content
            }
        }
    }

    private var attributes: [HTMLAttribute] {
        var style = Style()
        if let opacity = transition.insertionOpacity {
            style.append(.custom("--swui-enter-opacity", trimmedNumber(opacity)))
        }
        if let transform = transition.insertionTransform {
            style.append(.custom("--swui-enter-transform", transform))
        }
        if let opacity = transition.removalOpacity {
            style.append(.custom("--swui-exit-opacity", trimmedNumber(opacity)))
        }
        if let transform = transition.removalTransform {
            style.append(.custom("--swui-exit-transform", transform))
        }
        if let origin = transition.transformOrigin {
            style.append(.custom("transform-origin", origin))
        }
        style.append(.custom("--swui-transition", animation.cssValue))
        return [
            .class("swui-transition"),
            styleAttribute(style),
            HTMLAttribute("data-swui-transition", "1"),
            HTMLAttribute("data-swui-exit-ms", "\(animation.totalDurationMilliseconds)"),
        ]
    }

    private var animation: Animation {
        transition.transitionAnimation ?? .easeInOut(duration: 0.3)
    }
}

public extension HTML {
    /// Associates a transition with this view's insertion and removal while it is
    /// conditionally present in its container.
    func transition(_ transition: AnyTransition) -> ModifiedContent<Self, TransitionModifier> {
        modifier(TransitionModifier(transition))
    }
}
