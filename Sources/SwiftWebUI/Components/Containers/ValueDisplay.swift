import SwiftHTML

public struct ValueDisplay: WebUIAttributeComponent {
    private let label: String?
    private let value: String
    private let attributes: [HTMLAttribute]

    public init(
        label: String? = nil,
        value: String,
        _ attributes: HTMLAttribute...
    ) {
        self.label = label
        self.value = value
        self.attributes = attributes
    }

    public init(
        label: String? = nil,
        value: Int,
        _ attributes: HTMLAttribute...
    ) {
        self.label = label
        self.value = String(value)
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        // The value readout composes the shared regular material; its accent-
        // tinted surface stays a per-component difference fed in as the material
        // tint, while the recipe owns the translucency, blur, rim, and refraction.
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-value-display \(MaterialClass.material) \(MaterialClass.regular)",
                styles: .custom("--swui-material-tint", "var(--swui-value-display-background)"),
                extra: attributes
            )
        ) {
            if let label {
                span(.class("swui-value-label")) {
                    label
                }
            }
            Element("output", attributes: [.class("swui-value"), .aria("live", "polite")]) {
                value
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(label: label, value: value, attributes: self.attributes + attributes)
    }

    private init(label: String?, value: String, attributes: [HTMLAttribute]) {
        self.label = label
        self.value = value
        self.attributes = attributes
    }
}
