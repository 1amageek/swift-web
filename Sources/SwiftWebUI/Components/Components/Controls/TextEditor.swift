import SwiftWebUITheme
import SwiftHTML

/// A control for editing multi-line text, mirroring SwiftUI `TextEditor`.
///
/// Lowers to a native `<textarea>`. The field composes the shared thin material
/// so its fill and backdrop blur track the active design style, matching
/// `TextField`.
public struct TextEditor: AttributeComponent {
    private let text: Binding<String>
    private let attributes: [HTMLAttribute]
    @Environment({ $0.isEnabled }) private var isEnabled: Bool
    @Environment({ $0.textFieldStyle }) private var textFieldStyle: TextFieldStyleKind

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
        // SwiftHTML renders a textarea value binding as text content for SSR,
        // while keeping it as a property binding for client-side patching.
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
                    .value(text),
                    .onInput { event in
                        text.wrappedValue = event.value ?? ""
                    },
                ] + disabledAttributes + attributes
            ),
            isVoid: false
        )
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text: text, attributes: self.attributes + attributes)
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }
}
