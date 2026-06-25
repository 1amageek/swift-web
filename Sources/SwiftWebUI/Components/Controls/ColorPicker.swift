import SwiftHTML

/// A control for selecting a color, mirroring SwiftUI `ColorPicker`.
///
/// Lowers to a native `<input type="color">`. Selection is bound as a
/// `#rrggbb` hex string, the value format the native color input uses; this
/// layer has no `Color` value type, so the hex string is the honest interface.
public struct ColorPicker<Label: HTML>: WebUIAttributeComponent {
    private let label: Label
    private let selection: Binding<String>
    private let attributes: [HTMLAttribute]
    @Environment(\.isEnabled) private var isEnabled: Bool

    public init(
        selection: Binding<String>,
        supportsOpacity: Bool = true,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.selection = selection
        self.attributes = attributes
    }

    private init(label: Label, selection: Binding<String>, attributes: [HTMLAttribute]) {
        self.label = label
        self.selection = selection
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        let selection = self.selection
        Element("label", attributes: [.class("swui-field swui-color-picker")]) {
            span(.class("swui-field-label")) {
                label
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
        Self(label: label, selection: selection, attributes: self.attributes + attributes)
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }
}

public extension ColorPicker where Label == text {
    init(
        _ title: String,
        selection: Binding<String>,
        supportsOpacity: Bool = true,
        _ attributes: HTMLAttribute...
    ) {
        self.init(label: text(title), selection: selection, attributes: attributes)
    }
}
