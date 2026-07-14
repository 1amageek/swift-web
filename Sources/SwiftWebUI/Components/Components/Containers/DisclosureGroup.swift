import SwiftWebUITheme
import SwiftHTML

/// A container that shows or hides its content behind a disclosure control,
/// mirroring SwiftUI `DisclosureGroup`.
///
/// Lowers to a native `<details>`/`<summary>` pair, so expansion works without
/// any client runtime. The surface composes the shared `regularMaterial`
/// recipe.
public struct DisclosureGroup<Label: HTML, Content: HTML>: AttributeComponent {
    private let label: Label
    private let isExpanded: Binding<Bool>?
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.isExpanded = nil
        self.attributes = []
        self.content = content()
    }

    public init(
        isExpanded: Binding<Bool>,
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.isExpanded = isExpanded
        self.attributes = []
        self.content = content()
    }

    private init(
        label: Label,
        isExpanded: Binding<Bool>?,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.label = label
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
                extra: openAttributes + attributes
            )
        ) {
            Element("summary", attributes: summaryAttributes) {
                label
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
            label: label,
            isExpanded: isExpanded,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private var openAttributes: [HTMLAttribute] {
        guard isExpanded?.wrappedValue == true else {
            return []
        }
        return [.open]
    }

    private var summaryAttributes: [HTMLAttribute] {
        var result: [HTMLAttribute] = [.class("swui-disclosure-summary")]
        if let isExpanded {
            result.append(.onClick {
                isExpanded.wrappedValue.toggle()
            })
        }
        return result
    }
}

public extension DisclosureGroup where Label == text {
    init(_ title: String, @HTMLBuilder content: () -> Content) {
        self.init(content: content) {
            title
        }
    }

    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(isExpanded: isExpanded, content: content) {
            title
        }
    }
}
