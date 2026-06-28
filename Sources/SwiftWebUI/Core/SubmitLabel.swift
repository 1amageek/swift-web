import SwiftWebUITheme
import SwiftHTML

/// A semantic label for the keyboard submit/return key, mirroring SwiftUI
/// `SubmitLabel`.
///
/// Exposes the subset of SwiftUI's cases that map faithfully to an HTML
/// `enterkeyhint`; cases without a clean web equivalent are intentionally not
/// surfaced rather than mapped approximately.
public enum SubmitLabel: Sendable {
    case done
    case go
    case next
    case search
    case send
    case `return`

    var enterKeyHint: EnterKeyHint {
        switch self {
        case .done:
            return .done
        case .go:
            return .go
        case .next:
            return .next
        case .search:
            return .search
        case .send:
            return .send
        case .return:
            return .enter
        }
    }
}
