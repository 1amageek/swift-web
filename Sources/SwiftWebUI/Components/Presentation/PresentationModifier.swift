import SwiftHTML

/// The shared overlay engine behind the presentation modifiers (`alert`,
/// `confirmationDialog`, `sheet`, `popover`).
///
/// It lowers to a native `<dialog>` rendered as a sibling of the anchor view.
/// The dialog is `display: none` until presented, so it costs no layout while
/// hidden. When `isPresented` is true the server renders the `open` attribute and
/// a `data-presented="true"` marker; the client runtime upgrades that
/// in-flow open dialog to a true top-layer modal via `showModal()` (see the
/// runtime's presentation reconciler). Native dismissal (Esc, outside tap, or the
/// platform close affordance) fires the `close` event, which syncs the binding
/// back to `false` — there is no silent desync.
///
/// Degradation is explicit, not silent: without the client runtime the dialog
/// still shows as an in-flow, CSS-positioned modal panel, but it is not lifted to
/// the browser top layer and outside-tap dismissal depends on native `closedby`
/// support. The binding still drives show/hide through the normal re-render path.
public struct PresentationModifier<PresentedContent: HTML>: ComponentModifier {
    private let kind: PresentationKind
    private let isPresented: Binding<Bool>
    private let onDismiss: (() -> Void)?
    private let presentedContent: PresentedContent

    @Environment(\.interactiveDismissDisabled) private var interactiveDismissDisabled

    init(
        kind: PresentationKind,
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @HTMLBuilder presentedContent: () -> PresentedContent
    ) {
        self.kind = kind
        self.isPresented = isPresented
        self.onDismiss = onDismiss
        self.presentedContent = presentedContent()
    }

    /// The dialog's light dismiss policy after applying the environment opt-out.
    ///
    /// `interactiveDismissDisabled` forces `none` so neither a backdrop tap nor
    /// Esc can dismiss the dialog; otherwise the kind's default (`any`) keeps
    /// light dismissal. The runtime reconciler binds its backdrop handler only
    /// for `any`, so `none` is honored both natively and in the reconciler.
    private var effectiveClosedBy: DialogClosedBy {
        interactiveDismissDisabled ? .none : kind.closedBy
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        content
        Element("dialog", attributes: dialogAttributes) {
            Element(
                "div",
                attributes: [.class("swui-presentation-surface")]
            ) {
                presentedContent
            }
        }
    }

    private var dialogAttributes: [HTMLAttribute] {
        let isPresented = self.isPresented
        let onDismiss = self.onDismiss
        var attributes: [HTMLAttribute] = [
            .class("swui-presentation \(kind.cssClass) \(MaterialClass.material) \(MaterialClass.thick)"),
            .role(kind.role),
            HTMLAttribute("data-presented", isPresented.wrappedValue ? "true" : "false"),
            .closedby(effectiveClosedBy),
            .event("close") { _ in
                // React only to a real close so the idempotent reconciliation
                // pass cannot loop. Dismissal owns the binding write-back.
                if isPresented.wrappedValue {
                    isPresented.wrappedValue = false
                    onDismiss?()
                }
            },
        ]
        if isPresented.wrappedValue {
            attributes.append(.open)
        }
        return attributes
    }
}

public extension HTML {
    /// Presents an alert when `isPresented` is true, mirroring SwiftUI
    /// `alert(_:isPresented:actions:)`.
    func alert<Actions: HTML>(
        _ title: String,
        isPresented: Binding<Bool>,
        @HTMLBuilder actions: () -> Actions
    ) -> some HTML {
        let actions = actions()
        return modifier(
            PresentationModifier(kind: .alert, isPresented: isPresented) {
                Element("h2", attributes: [.class("swui-presentation-title")]) { title }
                Element("div", attributes: [.class("swui-presentation-actions")]) { actions }
            }
        )
    }

    /// Presents an alert with a message, mirroring SwiftUI
    /// `alert(_:isPresented:actions:message:)`.
    func alert<Actions: HTML, Message: HTML>(
        _ title: String,
        isPresented: Binding<Bool>,
        @HTMLBuilder actions: () -> Actions,
        @HTMLBuilder message: () -> Message
    ) -> some HTML {
        let actions = actions()
        let message = message()
        return modifier(
            PresentationModifier(kind: .alert, isPresented: isPresented) {
                Element("h2", attributes: [.class("swui-presentation-title")]) { title }
                Element("div", attributes: [.class("swui-presentation-message")]) { message }
                Element("div", attributes: [.class("swui-presentation-actions")]) { actions }
            }
        )
    }

    /// Presents a confirmation dialog when `isPresented` is true, mirroring
    /// SwiftUI `confirmationDialog(_:isPresented:titleVisibility:actions:)`.
    func confirmationDialog<Actions: HTML>(
        _ title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @HTMLBuilder actions: () -> Actions
    ) -> some HTML {
        let actions = actions()
        // No message: `automatic` hides the title, matching SwiftUI.
        let showsTitle = titleVisibility == .visible
        return modifier(
            PresentationModifier(kind: .confirmationDialog, isPresented: isPresented) {
                if showsTitle {
                    Element("h2", attributes: [.class("swui-presentation-title")]) { title }
                }
                Element("div", attributes: [.class("swui-presentation-actions")]) { actions }
            }
        )
    }

    /// Presents a confirmation dialog with a message, mirroring SwiftUI
    /// `confirmationDialog(_:isPresented:titleVisibility:actions:message:)`.
    func confirmationDialog<Actions: HTML, Message: HTML>(
        _ title: String,
        isPresented: Binding<Bool>,
        titleVisibility: Visibility = .automatic,
        @HTMLBuilder actions: () -> Actions,
        @HTMLBuilder message: () -> Message
    ) -> some HTML {
        let actions = actions()
        let message = message()
        // With a message, `automatic` shows the title, matching SwiftUI.
        let showsTitle = titleVisibility != .hidden
        return modifier(
            PresentationModifier(kind: .confirmationDialog, isPresented: isPresented) {
                if showsTitle {
                    Element("h2", attributes: [.class("swui-presentation-title")]) { title }
                }
                Element("div", attributes: [.class("swui-presentation-message")]) { message }
                Element("div", attributes: [.class("swui-presentation-actions")]) { actions }
            }
        )
    }

    /// Presents a sheet when `isPresented` is true, mirroring SwiftUI
    /// `sheet(isPresented:onDismiss:content:)`.
    func sheet<Content: HTML>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        @HTMLBuilder content: () -> Content
    ) -> some HTML {
        let content = content()
        return modifier(
            PresentationModifier(kind: .sheet, isPresented: isPresented, onDismiss: onDismiss) {
                content
            }
        )
    }

    /// Presents a popover when `isPresented` is true, mirroring SwiftUI
    /// `popover(isPresented:content:)`.
    func popover<Content: HTML>(
        isPresented: Binding<Bool>,
        @HTMLBuilder content: () -> Content
    ) -> some HTML {
        let content = content()
        return modifier(
            PresentationModifier(kind: .popover, isPresented: isPresented) {
                content
            }
        )
    }
}
