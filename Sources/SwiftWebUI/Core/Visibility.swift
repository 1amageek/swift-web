/// The visibility of a UI element, mirroring SwiftUI `Visibility`.
///
/// Used by presentation modifiers such as `confirmationDialog(titleVisibility:)`
/// to control whether an accessory (the title) is shown.
public enum Visibility: Sendable, Hashable {
    /// Resolve the visibility from context. For a confirmation dialog title this
    /// hides the title unless a message is also supplied.
    case automatic
    /// Always show the element.
    case visible
    /// Always hide the element.
    case hidden
}
