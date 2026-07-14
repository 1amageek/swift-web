import SwiftWebUITheme
import SwiftHTML

/// A control for selecting a color, mirroring SwiftUI `ColorPicker`.
///
/// Lowers to a native `<input type="color">`. Selection is bound as a
/// `#rrggbb` hex string, the value format the native color input uses; this
/// layer has no `Color` value type, so the hex string is the honest interface.
public struct ColorPicker<Label: HTML>: AttributeComponent {
    private let label: Label
    private let selection: Binding<String>
    /// Whether the picker should allow adjusting the selected color's opacity.
    ///
    /// The web `<input type="color">` cannot represent an alpha component, so
    /// the selected value is always fully opaque regardless of this flag. The
    /// value is retained for canonical call-site compatibility and will be
    /// wired to the input once browsers support alpha in the native color
    /// control.
    private let supportsOpacity: Bool
    private let attributes: [HTMLAttribute]
    @Environment({ $0.isEnabled }) private var isEnabled: Bool

    public init(
        selection: Binding<String>,
        supportsOpacity: Bool = true,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.selection = selection
        self.supportsOpacity = supportsOpacity
        self.attributes = attributes
    }

    private init(
        label: Label,
        selection: Binding<String>,
        supportsOpacity: Bool,
        attributes: [HTMLAttribute]
    ) {
        self.label = label
        self.selection = selection
        self.supportsOpacity = supportsOpacity
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
        Self(
            label: label,
            selection: selection,
            supportsOpacity: supportsOpacity,
            attributes: self.attributes + attributes
        )
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
        self.init(
            label: text(title),
            selection: selection,
            supportsOpacity: supportsOpacity,
            attributes: attributes
        )
    }
}
