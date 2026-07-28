import SwiftHTML

public struct GridRow<Content: Component>: AttributeComponent {
    private let alignment: VerticalAlignment?
    private let attributes: [HTMLAttribute]
    private let childContent: Content
    let cellCount: Int

    public init(
        alignment: VerticalAlignment? = nil,
        _ attributes: HTMLAttribute...,
        @GridRowContentBuilder content: () -> GridRowContent<Content>
    ) {
        let rowContent = content()
        self.alignment = alignment
        self.attributes = attributes
        self.childContent = rowContent.content
        self.cellCount = rowContent.cellCount
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid-row",
                styles: rowStyles,
                extra: attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            alignment: alignment,
            attributes: self.attributes + attributes,
            content: childContent,
            cellCount: cellCount
        )
    }

    private init(
        alignment: VerticalAlignment?,
        attributes: [HTMLAttribute],
        content: Content,
        cellCount: Int
    ) {
        self.alignment = alignment
        self.attributes = attributes
        self.childContent = content
        self.cellCount = cellCount
    }

    private var rowStyles: Style {
        var styles = Style { }
        if let alignment {
            styles = styles.custom(
                "--swui-grid-cell-vertical-alignment",
                alignment.gridAlignItems
            )
        }
        return styles
    }
}
