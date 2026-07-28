import SwiftWebUITheme
import SwiftHTML

/// A container that shows or hides its content behind a disclosure control,
/// mirroring SwiftUI `DisclosureGroup`.
///
/// Lowers to a native `<details>`/`<summary>` pair, so expansion works without
/// any client runtime. The surface composes the shared `regularMaterial`
/// recipe.
public struct DisclosureGroup<Label: Component, Content: Component>: AttributeComponent {
    private let label: Label
    private let isExpanded: Binding<Bool>?
    private let attributes: [HTMLAttribute]
    private let childContent: Content

    public init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.isExpanded = nil
        self.attributes = []
        self.childContent = content()
    }

    public init(
        isExpanded: Binding<Bool>,
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.label = label()
        self.isExpanded = isExpanded
        self.attributes = []
        self.childContent = content()
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
            label: text(title),
            isExpanded: nil,
            attributes: [],
            content: content()
        )
    }

    init(
        _ title: String,
        isExpanded: Binding<Bool>,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(
            label: text(title),
            isExpanded: isExpanded,
            attributes: [],
            content: content()
        )
    }
}
