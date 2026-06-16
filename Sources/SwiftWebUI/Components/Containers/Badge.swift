import SwiftHTML

public struct Badge: WebUIAttributeComponent {
    private let text: String
    private let attributes: [HTMLAttribute]

    public init(_ text: String, _ attributes: HTMLAttribute...) {
        self.text = text
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        // Compose the shared thin material so the badge picks up the active
        // design style's backdrop blur, rim, and refraction. The semantic raised
        // surface stays a per-badge difference, fed in as the material tint; the
        // recipe owns the translucency, so the tint stays an opaque hue.
        Element(
            "span",
            attributes: mergedAttributes(
                class: "swui-badge \(MaterialClass.material) \(MaterialClass.thin)",
                styles: .custom("--swui-material-tint", "var(--swui-badge-background)"),
                extra: attributes
            )
        ) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, attributes: self.attributes + attributes)
    }

    private init(_ text: String, attributes: [HTMLAttribute]) {
        self.text = text
        self.attributes = attributes
    }
}
