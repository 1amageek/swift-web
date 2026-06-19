import SwiftHTML

/// A container that shows or hides its content behind a disclosure control,
/// mirroring SwiftUI `DisclosureGroup`.
///
/// Lowers to a native `<details>`/`<summary>` pair, so expansion works without
/// any client runtime. The surface composes the shared `regularMaterial`
/// recipe.
public struct DisclosureGroup<Content: HTML>: WebUIAttributeComponent {
    private let title: String
    private let isExpanded: Bool
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        _ title: String,
        isExpanded: Bool = false,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.title = title
        self.isExpanded = isExpanded
        self.attributes = attributes
        self.content = content()
    }

    private init(
        title: String,
        isExpanded: Bool,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.title = title
        self.isExpanded = isExpanded
        self.attributes = attributes
        self.content = content
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "details",
            attributes: mergedAttributes(
                class: "swui-disclosure-group \(MaterialClass.material) \(MaterialClass.regular)",
                extra: (isExpanded ? [HTMLAttribute.open] : []) + attributes
            )
        ) {
            summary(.class("swui-disclosure-summary")) {
                title
            }
            Element(
                "div",
                attributes: [.class("swui-disclosure-content")]
            ) {
                content
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            title: title,
            isExpanded: isExpanded,
            attributes: self.attributes + attributes,
            content: content
        )
    }
}
