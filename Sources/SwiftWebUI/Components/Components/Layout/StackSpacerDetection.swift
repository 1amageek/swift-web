import SwiftHTML

/// Greed a stack advertises on each absolute (page) axis.
struct AxisGreed {
    var horizontal: Bool
    var vertical: Bool

    static let none = AxisGreed(horizontal: false, vertical: false)

    func union(_ other: AxisGreed) -> AxisGreed {
        AxisGreed(
            horizontal: horizontal || other.horizontal,
            vertical: vertical || other.vertical
        )
    }
}

/// Resolves, at render time, whether a stack with the given content is greedy
/// on each absolute axis — i.e. whether a `Spacer` is reachable through the
/// content tree without crossing a sized `Frame`.
///
/// A `Spacer` makes its immediate stack greedy along that stack's axis, and a
/// greedy stack makes every enclosing stack greedy on the same axis. That
/// chain must reach arbitrarily far up, but must also stop at a `.frame(...)`:
/// SwiftUI's frame absorbs the child's greed and proposes its own fixed size.
/// A CSS `:has()` selector can express "greedy descendant" but not "greedy
/// descendant with no frame in between", so deep nesting or a bounding frame
/// fell outside a purely structural stylesheet. Resolving greed here — the way
/// `Grid` counts its columns at render time — lets a spacer at any depth mark
/// its whole ancestor chain, and lets a frame terminate that chain, using only
/// the direct `parent > .swui-fill-*` consumption rules in the stylesheet.
///
/// Nested stacks and layout-neutral modifiers (`padding`, `background`, ...)
/// are transparent to the search; a `Frame` and every other node terminate it.
/// Detection sees only statically typed nodes; dynamically produced spacers
/// (inside `ForEach`/`if`) are covered by the shallow `:has(> .swui-spacer)`
/// fallback rules in the root stylesheet.
func stackAxisGreed(_ content: Any, isHorizontal: Bool) -> AxisGreed {
    var greed = childrenGreed(of: content)
    if directChildren(of: content).contains(where: { $0 is Spacer }) {
        if isHorizontal {
            greed.horizontal = true
        } else {
            greed.vertical = true
        }
    }
    return greed
}

/// The direct children of a stack's content: the elements of a `TupleComponent`,
/// or the single node itself.
private func directChildren(of content: Any) -> [Any] {
    if String(describing: type(of: content)).hasPrefix("TupleComponent") {
        return Mirror(reflecting: content).children.map(\.value)
    }
    return [content]
}

private func childrenGreed(of content: Any) -> AxisGreed {
    directChildren(of: content).reduce(.none) { $0.union(greed(of: $1)) }
}

/// The greed a single node contributes to its enclosing stack.
private func greed(of value: Any) -> AxisGreed {
    if value is Spacer {
        // A spacer's axis is assigned by the stack that directly holds it.
        return .none
    }
    let name = String(describing: type(of: value))
    if name.hasPrefix("HStack<") || name.hasPrefix("LazyHStack<") {
        guard let content = childContent(of: value) else { return .none }
        return stackAxisGreed(content, isHorizontal: true)
    }
    if name.hasPrefix("VStack<") || name.hasPrefix("LazyVStack<") {
        guard let content = childContent(of: value) else { return .none }
        return stackAxisGreed(content, isHorizontal: false)
    }
    if name.hasPrefix("ModifiedContent<") {
        // padding/background/foreground and other layout-neutral wrappers do
        // not bound the greedy axis, so greed passes through them. `Frame` is a
        // distinct type (below), not a `ModifiedContent`.
        guard let content = childContent(of: value) else { return .none }
        return childrenGreed(of: content)
    }
    // `Frame` and every other node bound or terminate spacer greed.
    return .none
}

private func childContent(of value: Any) -> Any? {
    Mirror(reflecting: value).children.first { $0.label == "content" }?.value
}
