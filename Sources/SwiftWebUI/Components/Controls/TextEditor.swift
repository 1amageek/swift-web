import SwiftHTML

/// A control for editing multi-line text, mirroring SwiftUI `TextEditor`.
///
/// Lowers to a native `<textarea>`. The field composes the shared thin material
/// so its fill and backdrop blur track the active design style, matching
/// `TextField`.
public struct TextEditor: WebUIAttributeComponent {
    private let text: Binding<String>
    private let attributes: [HTMLAttribute]
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.textFieldStyle) private var textFieldStyle

    public init(text: Binding<String>, _ attributes: HTMLAttribute...) {
        self.text = text
        self.attributes = attributes
    }

    private init(text: Binding<String>, attributes: [HTMLAttribute]) {
        self.text = text
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        let text = self.text
        // `<textarea>` carries its value as text content, not an attribute, so
        // the bound value is server-rendered as the element's content and kept
        // in sync through `onInput`.
        Element(
            "textarea",
            attributes: mergedAttributes(
                class: controlClassName(
                    "swui-text-editor",
                    textFieldStyle.className,
                    MaterialClass.material,
                    MaterialClass.thin
                ),
                styles: .custom("--swui-material-tint", "var(--swui-field-background)"),
                extra: [
                    .onInput { event in
                        text.wrappedValue = event.value ?? ""
                    },
                ] + disabledAttributes + attributes
            ),
            isVoid: false
        ) {
            text.wrappedValue
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text: text, attributes: self.attributes + attributes)
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }
}
