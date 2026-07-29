import SwiftWebUITheme
import SwiftHTML

/// A container that shows or hides its content behind a disclosure control,
/// mirroring SwiftUI `DisclosureGroup`.
///
/// Lowers to a native `<details>`/`<summary>` pair, so expansion works without
/// any client runtime. The surface composes the shared `regularMaterial`
/// recipe.
public struct DisclosureGroup<Label: Component, Content: Component>: AttributeComponent {
    private let label: ComponentContent
    private let isExpanded: Binding<Bool>?
    private let attributes: [HTMLAttribute]
    private let childContent: ComponentContent

    public init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = HTMLBuilder.buildExpression(label())
        self.isExpanded = nil
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    public init(
        isExpanded: Binding<Bool>,
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = HTMLBuilder.buildExpression(label())
        self.isExpanded = isExpanded
        self.attributes = []
        self.childContent = HTMLBuilder.buildExpression(content())
    }

    private init(
        label: ComponentContent,
        isExpanded: Binding<Bool>?,
        attributes: [HTMLAttribute],
        content: ComponentContent
    ) {
        self.label = label
        self.isExpanded = isExpanded
        self.attributes = attributes
        self.childContent = content
    }

    @ComponentBuilder
    public var content: some Component {
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
                childContent
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            label: label,
            isExpanded: isExpanded,
            attributes: self.attributes + attributes,
            content: childContent
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
        self.init(
            label: HTMLBuilder.buildExpression(text(title)),
            isExpanded: nil,
            attributes: [],
            content: HTMLBuilder.buildExpression(content())
        )
    }

    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(
            label: HTMLBuilder.buildExpression(text(title)),
            isExpanded: isExpanded,
            attributes: [],
            content: HTMLBuilder.buildExpression(content())
        )
    }
}
