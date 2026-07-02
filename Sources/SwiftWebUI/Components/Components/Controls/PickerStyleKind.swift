import SwiftWebUITheme
/// The visual presentation of a `Picker`, mirroring SwiftUI `PickerStyle`.
///
/// Only the styles that map to an honest native HTML control are exposed. Web
/// has no wheel or palette equivalent, so those SwiftUI cases are intentionally
/// omitted rather than silently degraded to another control.
public enum PickerStyleKind: String, Codable, Sendable, Equatable {
    /// The system default. On the web this resolves to a pop-up menu, the same
    /// control SwiftUI picks for a picker in a form.
    case automatic
    /// A pop-up menu, lowered to a native `<select>`.
    case menu
    /// A horizontal segmented control, lowered to a `role="radiogroup"` of
    /// radio inputs that compose the shared `bar` material.
    case segmented
    /// An inline list of mutually exclusive options, lowered to a vertical
    /// `role="radiogroup"` of radio inputs with no surrounding chrome.
    case inline

    /// Whether the style lowers to a radio group rather than a `<select>`.
    var usesRadioGroup: Bool {
        switch self {
        case .automatic, .menu:
            false
        case .segmented, .inline:
            true
        }
    }
}
