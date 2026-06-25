import SwiftHTML

/// Whether the enclosing presentation refuses interactive dismissal.
///
/// `PresentationModifier` reads this to pick the dialog's light dismiss policy:
/// `false` (the default) keeps `closedby="any"` so a backdrop tap or Esc cancels
/// the dialog; `true` switches it to `closedby="none"` so neither the backdrop
/// nor Esc can close it and only an explicit action (a button that flips the
/// binding) dismisses it. The key is `internal` so `String(reflecting:)` yields a
/// stable `SwiftWebUI.<Name>` identity shared by the server and WASM binaries; it
/// is registered in `ClientEnvironmentRegistry.swiftWebUI`.
struct InteractiveDismissDisabledEnvironmentKey: ClientEnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var interactiveDismissDisabled: Bool {
        get { self[InteractiveDismissDisabledEnvironmentKey.self] }
        set { self[InteractiveDismissDisabledEnvironmentKey.self] = newValue }
    }
}

/// Disables interactive dismissal for a presentation in the subtree, mirroring
/// SwiftUI `interactiveDismissDisabled(_:)`.
///
/// Apply it to (or outside) the view that owns the presentation modifier so the
/// flag is in environment scope when the dialog renders. The presentation then
/// forgoes backdrop- and Esc-dismissal, forcing the user to make an explicit
/// choice; the binding still dismisses the dialog programmatically.
public struct InteractiveDismissDisabledModifier: ComponentModifier {
    private let isDisabled: Bool

    init(_ isDisabled: Bool) {
        self.isDisabled = isDisabled
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content.environment(InteractiveDismissDisabledEnvironmentKey.self, isDisabled)
    }
}

public extension HTML {
    /// Conditionally prevents the enclosing presentation from being dismissed
    /// interactively, mirroring SwiftUI `interactiveDismissDisabled(_:)`.
    ///
    /// When `isDisabled` is true the presentation no longer light-dismisses on a
    /// backdrop tap or Esc; it closes only when its binding is set back to false
    /// (for example by a button inside the dialog). Apply it outside the
    /// presentation modifier so the flag reaches the dialog through the
    /// environment:
    ///
    /// ```swift
    /// anchor
    ///     .alert("Delete this draft?", isPresented: $isPresented) { ... }
    ///     .interactiveDismissDisabled()
    /// ```
    func interactiveDismissDisabled(
        _ isDisabled: Bool = true
    ) -> ModifiedContent<Self, InteractiveDismissDisabledModifier> {
        modifier(InteractiveDismissDisabledModifier(isDisabled))
    }
}
