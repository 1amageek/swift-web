import SwiftHTML

/// The kind of overlay a presentation modifier lowers to.
///
/// Each kind maps to a `<dialog>` styling class, an ARIA role, and a light
/// dismiss policy. All kinds share the same `<dialog>` primitive; the kind only
/// selects chrome (centered alert vs. bottom sheet vs. anchored popover) and the
/// dismissal affordances appropriate to that presentation.
public enum PresentationKind: Sendable, Hashable {
    /// A modal that demands an explicit choice, mirroring SwiftUI `alert`.
    case alert
    /// A set of choices with an implicit cancel, mirroring SwiftUI
    /// `confirmationDialog`.
    case confirmationDialog
    /// A modal card, mirroring SwiftUI `sheet`.
    case sheet
    /// A transient overlay anchored to its source, mirroring SwiftUI `popover`.
    case popover

    /// The kind-specific CSS class that selects the overlay chrome.
    var cssClass: String {
        switch self {
        case .alert: return "swui-presentation-alert"
        case .confirmationDialog: return "swui-presentation-confirmation"
        case .sheet: return "swui-presentation-sheet"
        case .popover: return "swui-presentation-popover"
        }
    }

    /// The ARIA role for the dialog element.
    ///
    /// Alerts and confirmations interrupt the user for a decision, so they take
    /// `alertdialog`; sheets and popovers are non-interrupting surfaces and take
    /// `dialog`.
    var role: String {
        switch self {
        case .alert, .confirmationDialog: return "alertdialog"
        case .sheet, .popover: return "dialog"
        }
    }

    /// The native light dismiss policy for the dialog.
    ///
    /// Alerts dismiss only on a close request (Esc), forcing an explicit choice
    /// for outside taps; the other kinds also dismiss on an outside tap, matching
    /// their implicit-cancel semantics.
    var closedBy: DialogClosedBy {
        switch self {
        case .alert: return .closeRequest
        case .confirmationDialog, .sheet, .popover: return .any
        }
    }
}
