import SwiftWebUITheme
import SwiftHTML

public struct Grid<Content: HTML>: WebUIAttributeComponent {
    private let alignment: Alignment
    private let horizontalSpacing: Double?
    private let verticalSpacing: Double?
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: Alignment = .center,
        horizontalSpacing: Double? = nil,
        verticalSpacing: Double? = nil,
        @HTMLBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-grid",
                styles: Style {
                    .custom("--swui-grid-horizontal-spacing", gridSpacingValue(horizontalSpacing))
                    .custom("--swui-grid-vertical-spacing", gridSpacingValue(verticalSpacing))
                    .custom("--swui-grid-cell-horizontal-alignment", alignment.horizontal.textAlign)
                    .custom("--swui-grid-cell-vertical-alignment", alignment.vertical.gridAlignItems)
                },
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            alignment: alignment,
            horizontalSpacing: horizontalSpacing,
            verticalSpacing: verticalSpacing,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        alignment: Alignment,
        horizontalSpacing: Double?,
        verticalSpacing: Double?,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.alignment = alignment
        self.horizontalSpacing = horizontalSpacing
        self.verticalSpacing = verticalSpacing
        self.attributes = attributes
        self.content = content
    }
}

public struct GridRow<Content: HTML>: WebUIAttributeComponent {
    private let alignment: VerticalAlignment?
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        alignment: VerticalAlignment? = nil,
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.alignment = alignment
        self.attributes = attributes
        self.content = content()
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
        Self(alignment: alignment, attributes: self.attributes + attributes, content: content)
    }

    private init(alignment: VerticalAlignment?, attributes: [HTMLAttribute], content: Content) {
        self.alignment = alignment
        self.attributes = attributes
        self.content = content
    }

    private var rowStyles: Style {
        // The row's CSS grid layout lives in the `.swui-grid-row` rule; this only
        // overrides the vertical alignment for this row's cells when requested.
        var styles = Style { }
        if let alignment {
            styles = styles.custom("--swui-grid-cell-vertical-alignment", alignment.gridAlignItems)
        }
        return styles
    }
}

private func gridSpacingValue(_ spacing: Double?) -> String {
    spacing.map(pixelValue) ?? "var(--swui-stack-spacing)"
}

private extension VerticalAlignment {
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
