import SwiftHTML

/// How a text input automatically capitalizes content, mirroring SwiftUI
/// `TextInputAutocapitalization`.
///
/// Each value maps to the corresponding HTML `autocapitalize` keyword.
public struct TextInputAutocapitalization: Sendable, Equatable {
    let value: Autocapitalize

    public static let never = TextInputAutocapitalization(value: .none)
    public static let characters = TextInputAutocapitalization(value: .characters)
    public static let words = TextInputAutocapitalization(value: .words)
    public static let sentences = TextInputAutocapitalization(value: .sentences)
}
