import SwiftHTML

/// SwiftUI-canonical text-input modifiers that lower to the standard HTML form
/// attributes. They attach to the receiver's element, so on `TextField`,
/// `SecureField`, `TextEditor`, and `DatePicker` they land on the underlying
/// `<input>`/`<textarea>`.
public extension WebUIAttributeComponent {
    /// Sets the on-screen keyboard layout, mirroring SwiftUI `keyboardType(_:)`.
    /// Lowers to HTML `inputmode`; a type without a web equivalent emits nothing.
    func keyboardType(_ type: KeyboardType) -> Self {
        guard let mode = type.inputMode else {
            return self
        }
        return attribute(.inputmode(mode))
    }

    /// Sets the expected semantic content, mirroring SwiftUI
    /// `textContentType(_:)`. Lowers to HTML `autocomplete` to drive autofill.
    func textContentType(_ type: TextContentType) -> Self {
        attribute(.autocomplete(type.autocompleteToken))
    }

    /// Sets the keyboard submit-key label, mirroring SwiftUI `submitLabel(_:)`.
    /// Lowers to HTML `enterkeyhint`.
    func submitLabel(_ label: SubmitLabel) -> Self {
        attribute(.enterkeyhint(label.enterKeyHint))
    }

    /// Sets automatic capitalization, mirroring SwiftUI
    /// `textInputAutocapitalization(_:)`. Lowers to HTML `autocapitalize`.
    func textInputAutocapitalization(_ autocapitalization: TextInputAutocapitalization) -> Self {
        attribute(.autocapitalize(autocapitalization.value))
    }

    /// Disables autocorrection, mirroring SwiftUI `autocorrectionDisabled(_:)`.
    /// Lowers to HTML `autocorrect`.
    func autocorrectionDisabled(_ disable: Bool = true) -> Self {
        attribute(.autocorrect(disable ? .off : .on))
    }
}
