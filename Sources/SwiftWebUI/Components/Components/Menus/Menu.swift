import SwiftWebUITheme
import SwiftHTML

/// A control that presents a menu of actions, mirroring SwiftUI `Menu`.
///
/// Lowers to a native `<details>`/`<summary>` pair, so the pulldown opens and
/// closes without any client runtime. The summary is interactive glass; the
/// floating panel composes the shared `regularMaterial` recipe, matching the
/// other overlay chrome.
public struct Menu<Label: Component, Content: Component>: AttributeComponent {
    private let attributes: [HTMLAttribute]
    private let label: Label
    private let childContent: Content
    @Environment({ $0.menuStyle }) private var menuStyle: MenuStyleKind

    public init(
        @HTMLBuilder content: () -> Content,
        @HTMLBuilder label: () -> Label
    ) {
        self.attributes = []
        self.childContent = content()
        self.label = label()
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "details",
            attributes: mergedAttributes(class: controlClassName("swui-menu", menuStyle.className), extra: attributes)
        ) {
            Element(
                "summary",
                attributes: [
                    .class("swui-menu-label \(MaterialClass.glass) \(MaterialClass.interactive) \(MaterialClass.regular)"),
                ]
            ) {
                label
            }
            // No `role="menu"`: that role requires `menuitem` children, but the
            // content is arbitrary (buttons, links, toggles). A native
            // `<details>` disclosure of free content is the honest semantic.
            Element(
                "div",
                attributes: [
                    .class("swui-menu-content \(MaterialClass.material) \(MaterialClass.regular)"),
                ]
            ) {
                childContent
            }
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(attributes: self.attributes + attributes, content: childContent, label: label)
    }

    private init(attributes: [HTMLAttribute], content: Content, label: Label) {
        self.attributes = attributes
        self.childContent = content
        self.label = label
    }
}

public extension Menu where Label == text {
    init(_ title: String, @HTMLBuilder content: () -> Content) {
        self.init(attributes: [], content: content(), label: text(title))
    }
}
