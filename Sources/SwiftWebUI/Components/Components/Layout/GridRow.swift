import SwiftHTML

public struct GridRow<Content: HTML>: AttributeComponent {
    private let alignment: VerticalAlignment?
    private let attributes: [HTMLAttribute]
    private let content: Content
    let cellCount: Int

    public init(
        alignment: VerticalAlignment? = nil,
        _ attributes: HTMLAttribute...,
        @GridRowContentBuilder content: () -> GridRowContent<Content>
    ) {
        let rowContent = content()
        self.alignment = alignment
        self.attributes = attributes
        self.content = rowContent.content
        self.cellCount = rowContent.cellCount
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid-row",
                styles: rowStyles,
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            alignment: alignment,
            attributes: self.attributes + attributes,
            content: content,
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
        self.content = content
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
