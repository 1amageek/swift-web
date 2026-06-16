import SwiftHTML

/// A control for selecting a color, mirroring SwiftUI `ColorPicker`.
///
/// Lowers to a native `<input type="color">`. Selection is bound as a
/// `#rrggbb` hex string, the value format the native color input uses; this
/// layer has no `Color` value type, so the hex string is the honest interface.
public struct ColorPicker: WebUIAttributeComponent {
    private let title: String
    private let selection: Binding<String>
    private let attributes: [HTMLAttribute]
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        selection: Binding<String>,
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.selection = selection
        self.attributes = attributes
    }

    private init(title: String, selection: Binding<String>, attributes: [HTMLAttribute]) {
        self.title = title
        self.selection = selection
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        let selection = self.selection
        Element("label", attributes: [.class("swui-field swui-color-picker")]) {
            span(.class("swui-field-label")) {
                title
            }
            Element(
                "input",
                attributes: mergedAttributes(
                    class: "swui-color-picker-input",
                    extra: [
                        .type(.color),
                        .value(selection),
                        .onInput { event in
                            selection.wrappedValue = event.value ?? ""
                        },
                    ] + disabledAttributes + attributes
                ),
                isVoid: true
            )
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, selection: selection, attributes: self.attributes + attributes)
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }
}
