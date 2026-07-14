import SwiftWebUITheme
import SwiftHTML

public struct GridSystem<Content: HTML>: AttributeComponent {
    private let columns: Int
    private let gutter: Space
    private let verticalPadding: Space
    private let attributes: [HTMLAttribute]
    private let content: Content

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
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid-system",
                styles: styles,
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            columns: columns,
            gutter: gutter,
            verticalPadding: verticalPadding,
            attributes: self.attributes + attributes,
            content: content
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
        self.content = content
    }

    private var styles: Style {
        Style {
            .custom("--swui-grid-system-columns", "\(columns)")
            .custom("--swui-grid-system-gutter", gutter.rawValue)
            .paddingBlock(verticalPadding.rawValue)
        }
    }
}
