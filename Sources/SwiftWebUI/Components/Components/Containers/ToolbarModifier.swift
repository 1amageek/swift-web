import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

public extension HTML {
    /// Attaches toolbar content to this view, mirroring SwiftUI's
    /// `.toolbar { ToolbarItem(placement:) { ... } }`.
    ///
    /// The toolbar is UI-layer chrome: it lays out above (and, for
    /// `.bottomBar`/`.status` placements, below) the content and must not
    /// depend on the content layer. Items route into leading, principal,
    /// trailing, and bottom regions by their placement; empty bars and regions
    /// collapse.
    func toolbar<Items: HTML>(@HTMLBuilder content: () -> Items) -> some HTML {
        ToolbarLayout(content: self, items: content())
    }
}

struct ToolbarLayout<Content: HTML, Items: HTML>: Component {
    private let content: Content
    private let items: Items

    init(content: Content, items: Items) {
        self.content = content
        self.items = items
    }

    @HTMLBuilder
    var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-toolbar-layout \(LayoutClass.fillHorizontal)",
                extra: []
            )
        ) {
            Element("header", attributes: [.class("\(Self.barClassName) swui-toolbar-top")]) {
                Element("div", attributes: [.class("swui-toolbar-zone swui-toolbar-leading")]) {
                    items
                        .transformEnvironment({ $0.toolbarRegion = ToolbarItemPlacement.Region.leading })
                }
                Element("div", attributes: [.class("swui-toolbar-zone swui-toolbar-principal")]) {
                    items
                        .transformEnvironment({ $0.toolbarRegion = ToolbarItemPlacement.Region.principal })
                }
                Element("div", attributes: [.class("swui-toolbar-zone swui-toolbar-trailing")]) {
                    items
                        .transformEnvironment({ $0.toolbarRegion = ToolbarItemPlacement.Region.trailing })
                }
            }
            content
            Element("footer", attributes: [.class("\(Self.barClassName) swui-toolbar-bottom")]) {
                items
                    .transformEnvironment({ $0.toolbarRegion = ToolbarItemPlacement.Region.bottom })
            }
        }
    }

    // The bar composes the `bar` material — one step more frosted than a
    // content container — matching the toolbar chrome recipe.
    private static var barClassName: String {
        controlClassName(
            "swui-toolbar",
            LayoutClass.fillHorizontal,
            MaterialClass.material,
            MaterialClass.bar,
            Space.small.gapClassName.rawValue
        )
    }
}
