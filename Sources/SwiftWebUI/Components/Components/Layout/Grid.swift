import SwiftWebUITheme
import SwiftHTML

public struct Grid<Content: HTML>: AttributeComponent {
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
                    .custom("--swui-grid-columns", "\(columnCount)")
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

extension Grid {
    /// The shared column count: the widest row's cell count. SwiftUI sizes
    /// column i by the widest cell i across ALL rows; the stylesheet needs
    /// the track count to own those shared columns, so it is counted here
    /// at render time from the statically built row tuples. Dynamic rows
    /// (ForEach) cannot be counted this way and contribute nothing; a grid
    /// made only of dynamic rows falls back to one column.
    private var columnCount: Int {
        func widestRow(in value: Any) -> Int {
            if let row = value as? any GridRowCellCounting {
                return row.cellCount
            }
            let typeName = String(describing: type(of: value))
            guard typeName.hasPrefix("TupleComponent") else {
                return 0
            }
            return Mirror(reflecting: value).children
                .map { widestRow(in: $0.value) }
                .max() ?? 0
        }
        return Swift.max(1, widestRow(in: content))
    }
}

/// The cell-counting surface `Grid` uses to size its shared column tracks.
protocol GridRowCellCounting {
    var cellCount: Int { get }
}

extension GridRow: GridRowCellCounting {
    var cellCount: Int {
        let typeName = String(describing: type(of: content))
        guard typeName.hasPrefix("TupleComponent") else {
            return 1
        }
        return Mirror(reflecting: content).children.count
    }
}

public struct GridRow<Content: HTML>: AttributeComponent {
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
