import SwiftHTML

/// The keyboard layout to display for text entry, mirroring SwiftUI
/// `keyboardType(_:)` / UIKit `UIKeyboardType`.
///
/// Each case maps to the closest HTML `inputmode`. Cases without a faithful web
/// equivalent expose no `inputmode` — the platform default keyboard — rather
/// than emitting a misleading hint.
public enum KeyboardType: Sendable {
    case `default`
    case asciiCapable
    case numbersAndPunctuation
    case URL
    case numberPad
    case phonePad
    case namePhonePad
    case emailAddress
    case decimalPad
    case twitter
    case webSearch
    case asciiCapableNumberPad

    var inputMode: InputMode? {
        switch self {
        case .numberPad, .asciiCapableNumberPad:
            return .numeric
        case .decimalPad:
            return .decimal
        case .phonePad:
            return .tel
        case .emailAddress:
            return .email
        case .URL:
            return .url
        case .webSearch:
            return .search
        case .default, .asciiCapable, .numbersAndPunctuation, .namePhonePad, .twitter:
            return nil
        }
    }
}
