import SwiftWebUITheme
import SwiftHTML

public struct ScrollView<Content: Component>: AttributeComponent {
    private let axes: Axis.Set
    private let showsIndicators: Bool
    private let attributes: [HTMLAttribute]
    private let childContent: Content

    public init(
        _ axes: Axis.Set = .vertical,
        showsIndicators: Bool = true,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.attributes = attributes
        self.childContent = content()
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: className,
                styles: styles,
                extra: attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(axes: axes, showsIndicators: showsIndicators, attributes: self.attributes + attributes, content: childContent)
    }

    private init(axes: Axis.Set, showsIndicators: Bool, attributes: [HTMLAttribute], content: Content) {
        self.axes = axes
        self.showsIndicators = showsIndicators
        self.attributes = attributes
        self.childContent = content
    }

    private var className: String {
        showsIndicators ? "swui-scroll-view" : "swui-scroll-view swui-scroll-view-hidden-indicators"
    }

    private var styles: Style {
        Style {
            .overflowX(axes.contains(.horizontal) ? "auto" : "hidden")
            .overflowY(axes.contains(.vertical) ? "auto" : "hidden")
        }
    }
}
