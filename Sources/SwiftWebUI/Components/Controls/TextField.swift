import SwiftHTML

public struct TextField: WebUIAttributeComponent {
    private let title: String
    private let type: InputType
    private let attributes: [HTMLAttribute]
    @Environment(\.controlSize) private var controlSize
    @Environment(\.isEnabled) private var isEnabled

    public init(
        _ title: String,
        text: Binding<String>,
        _ attributes: HTMLAttribute...
    ) {
        self.title = title
        self.type = .text
        self.attributes = [.value(text), .onInput { event in
            text.wrappedValue = event.value ?? ""
        }] + attributes
    }

    init(
        title: String,
        type: InputType,
        attributes: [HTMLAttribute]
    ) {
        self.title = title
        self.type = type
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("label", attributes: [.class("swui-field \(LayoutClass.fillHorizontal)")]) {
            span(.class("swui-field-label")) {
                title
            }
            // The field composes the shared thin material so its fill and
            // backdrop blur track the active design style. `<input>` is a
            // replaced element, so the `::before` rim/refraction overlay does not
            // paint here — the fill and blur (the missing piece this primitive
            // fixes) still apply. The raised surface stays an opaque tint.
            Element(
                "input",
                attributes: mergedAttributes(
                    class: "swui-text-field \(controlSize.className) \(MaterialClass.material) \(MaterialClass.thin)",
                    styles: .custom("--swui-material-tint", "var(--swui-field-background)"),
                    extra: typeAttribute + [.placeholder(title)] + disabledAttributes + attributes
                ),
                isVoid: true
            )
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(title: title, type: type, attributes: self.attributes + attributes)
    }

    private var disabledAttributes: [HTMLAttribute] {
        isEnabled ? [] : [.disabled, .aria("disabled", "true")]
    }

    // The default `type` is only emitted when the caller did not pass an
    // explicit one. A passed `.type(.email)` / `.number` / `.url` / `.search`
    // then renders as the sole `type` attribute — duplicate attributes are
    // invalid HTML and the browser keeps the first, so the default must yield
    // rather than emit a second `type`.
    private var typeAttribute: [HTMLAttribute] {
        let hasExplicitType = attributes.contains { $0.name == "type" }
        return hasExplicitType ? [] : [.type(type)]
    }
}
