import SwiftWebUITheme
import SwiftHTML

public struct GridSystem<Content: Component>: AttributeComponent {
    private let columns: Int
    private let gutter: Space
    private let verticalPadding: Space
    private let attributes: [HTMLAttribute]
    private let childContent: Content

    public init(
        columns: Int = 12,
        gutter: Space = .large,
        verticalPadding: Space = .xlarge,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.columns = max(columns, 1)
        self.gutter = gutter
        self.verticalPadding = verticalPadding
        self.attributes = attributes
        self.childContent = content()
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid-system",
                styles: styles,
                extra: attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            columns: columns,
            gutter: gutter,
            verticalPadding: verticalPadding,
            attributes: self.attributes + attributes,
            content: childContent
        )
    }

    private init(
        columns: Int,
        gutter: Space,
        verticalPadding: Space,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.columns = columns
        self.gutter = gutter
        self.verticalPadding = verticalPadding
        self.attributes = attributes
        self.childContent = content
    }

    private var styles: Style {
        Style {
            .custom("--swui-grid-system-columns", "\(columns)")
            .custom("--swui-grid-system-gutter", gutter.rawValue)
            .paddingBlock(verticalPadding.rawValue)
        }
    }
}
