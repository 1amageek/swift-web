import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

@available(*, deprecated, message: "Use the toolbar { ToolbarItem(placement:) { ... } } modifier, matching SwiftUI")
public struct Toolbar<Content: HTML>: WebUIAttributeComponent {
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(_ attributes: HTMLAttribute..., @HTMLBuilder content: () -> Content) {
        self.attributes = attributes
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        // A toolbar is chrome that floats over content, so it composes the `bar`
        // material — one step more frosted than a content container. The fill, backdrop blur,
        // rim, and refraction all come from the shared recipe; the toolbar keeps
        // only its own padding and radius (in the `.swui-toolbar` rule).
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName(
                    "swui-toolbar",
                    LayoutClass.fillHorizontal,
                    MaterialClass.material,
                    MaterialClass.bar,
                    Space.small.gapClassName.rawValue
                ),
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(attributes: self.attributes + attributes, content: content)
    }

    private init(attributes: [HTMLAttribute], content: Content) {
        self.attributes = attributes
        self.content = content
    }
}
