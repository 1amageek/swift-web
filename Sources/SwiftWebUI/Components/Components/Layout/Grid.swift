import SwiftWebUITheme
import SwiftHTML

public struct Grid<Content: Component>: AttributeComponent {
    private let alignment: Alignment
    private let horizontalSpacing: Double?
    private let verticalSpacing: Double?
    private let attributes: [HTMLAttribute]
    private let childContent: Content
    private let columnCount: Int

    public init(
        alignment: Alignment = .center,
        horizontalSpacing: Double? = nil,
        verticalSpacing: Double? = nil,
        @GridContentBuilder content: () -> GridContent<Content>
    ) {
        let gridContent = content()
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.attributes = []
        self.childContent = gridContent.content
        self.columnCount = Swift.max(1, gridContent.maximumColumnCount)
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid",
                styles: Style {
                    .custom("--swui-grid-horizontal-spacing", gridSpacingValue(horizontalSpacing))
                    .custom("--swui-grid-vertical-spacing", gridSpacingValue(verticalSpacing))
                    .custom("--swui-grid-cell-horizontal-alignment", alignment.horizontal.textAlign)
                    .custom("--swui-grid-cell-vertical-alignment", alignment.vertical.gridAlignItems)
                    .custom("--swui-grid-columns", "\(columnCount)")
                },
                extra: attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            alignment: alignment,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            attributes: self.attributes + attributes,
            content: childContent,
            columnCount: columnCount
        )
    }

    private init(
        alignment: Alignment,
        horizontalSpacing: Double?,
        verticalSpacing: Double?,
        attributes: [HTMLAttribute],
        content: Content,
        columnCount: Int
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.attributes = attributes
        self.childContent = content
        self.columnCount = columnCount
    }
}

private func gridSpacingValue(_ spacing: Double?) -> String {
    spacing.map(pixelValue) ?? "var(--swui-stack-spacing)"
}

extension VerticalAlignment {
    /// Maps a SwiftUI vertical alignment to the CSS Grid `align-items` value used
    /// to position a row's cells within the row's track.
    var gridAlignItems: String {
        switch self {
        case .top:
            "start"
        case .center, .stretch:
            "center"
        case .bottom:
            "end"
        }
    }
}
