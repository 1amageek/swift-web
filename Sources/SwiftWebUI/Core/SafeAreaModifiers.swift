import SwiftHTML

public struct SafeAreaRegions: OptionSet, Sendable, Equatable {
    public let rawValue: Int

    public init(rawValue: Int) {
        self.rawValue = rawValue
    }

    public static let container = SafeAreaRegions(rawValue: 1 << 0)
    public static let keyboard = SafeAreaRegions(rawValue: 1 << 1)
    public static let all: SafeAreaRegions = [.container, .keyboard]
}

public struct SafeAreaInsetModifier<InsetContent: HTML>: ComponentModifier {
    private let edge: Edge
    private let alignment: Alignment
    private let spacing: WebUILength?
    private let insetContent: InsetContent

    init(
        edge: Edge,
        alignment: Alignment,
        spacing: WebUILength?,
        @HTMLBuilder content: () -> InsetContent
    ) {
        self.edge = edge
        self.alignment = alignment
        self.spacing = spacing
        self.insetContent = content()
    }

    @HTMLBuilder
    public func body(content: ModifierContent) -> some HTML {
        Element(
            "div",
            attributes: [
                .class("swui-safe-area-inset swui-safe-area-inset-\(edge.cssName)"),
                styleAttribute(wrapperStyle),
            ]
        ) {
            if edge == .top || edge == .leading {
                inset
                content
            } else {
                content
                inset
            }
        }
    }

    @HTMLBuilder
    private var inset: some HTML {
        Element(
            "div",
            attributes: [
                .class("swui-safe-area-inset-content"),
                styleAttribute(insetStyle),
            ]
        ) {
            insetContent
        }
    }

    private var wrapperStyle: Style {
        switch edge {
        case .top, .bottom:
            Style {
                .display("flex")
                .flexDirection("column")
                .gap(spacing?.cssValue ?? "0")
            }
        case .leading, .trailing:
            Style {
                .display("flex")
                .flexDirection("row")
                .gap(spacing?.cssValue ?? "0")
            }
        }
    }

    private var insetStyle: Style {
        Style {
            .alignSelf(alignment.vertical.cssSelfAlignment)
            .justifySelf(alignment.horizontal.cssSelfAlignment)
        }
    }
}

public extension HTML {
    func ignoresSafeArea(
        _ regions: SafeAreaRegions = .all,
        edges: Edge.Set = .all
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        return modifier(HTMLAttributeModifier([
            .data("safe-area-regions", regions.cssName),
            styleAttribute(safeAreaExpansionStyle(edges: edges)),
        ]))
    }

    func safeAreaPadding(_ insets: EdgeInsets) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(safeAreaPaddingStyle(insets: insets))]))
    }

    func safeAreaPadding(
        _ edges: Edge.Set = .all,
        _ length: WebUILength? = nil
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(safeAreaPaddingStyle(edges: edges, length: length))]))
    }

    func safeAreaInset<InsetContent: HTML>(
        edge: VerticalEdge,
        alignment: HorizontalAlignment = .center,
        spacing: WebUILength? = nil,
        @HTMLBuilder content: () -> InsetContent
    ) -> ModifiedContent<Self, SafeAreaInsetModifier<InsetContent>> {
        modifier(SafeAreaInsetModifier(
            edge: edge.edge,
            alignment: Alignment(horizontal: alignment, vertical: edge.defaultVerticalAlignment),
            spacing: spacing,
            content: content
        ))
    }

    func safeAreaInset<InsetContent: HTML>(
        edge: HorizontalEdge,
        alignment: VerticalAlignment = .center,
        spacing: WebUILength? = nil,
        @HTMLBuilder content: () -> InsetContent
    ) -> ModifiedContent<Self, SafeAreaInsetModifier<InsetContent>> {
        modifier(SafeAreaInsetModifier(
            edge: edge.edge,
            alignment: Alignment(horizontal: edge.defaultHorizontalAlignment, vertical: alignment),
            spacing: spacing,
            content: content
        ))
    }
}

func safeAreaExpansionStyle(edges: Edge.Set) -> Style {
    var style = Style()
    if edges.contains(.top) {
        style.append(.marginTop("calc(env(safe-area-inset-top) * -1)"))
        style.append(.paddingTop("env(safe-area-inset-top)"))
    }
    if edges.contains(.leading) {
        style.append(.marginLeft("calc(env(safe-area-inset-left) * -1)"))
        style.append(.paddingLeft("env(safe-area-inset-left)"))
    }
    if edges.contains(.bottom) {
        style.append(.marginBottom("calc(env(safe-area-inset-bottom) * -1)"))
        style.append(.paddingBottom("env(safe-area-inset-bottom)"))
    }
    if edges.contains(.trailing) {
        style.append(.marginRight("calc(env(safe-area-inset-right) * -1)"))
        style.append(.paddingRight("env(safe-area-inset-right)"))
    }
    return style
}

func safeAreaPaddingStyle(edges: Edge.Set, length: WebUILength?) -> Style {
    let extra = length?.cssValue ?? "0px"
    var style = Style()
    if edges.contains(.top) {
        style.append(.paddingTop("calc(env(safe-area-inset-top) + \(extra))"))
    }
    if edges.contains(.leading) {
        style.append(.paddingLeft("calc(env(safe-area-inset-left) + \(extra))"))
    }
    if edges.contains(.bottom) {
        style.append(.paddingBottom("calc(env(safe-area-inset-bottom) + \(extra))"))
    }
    if edges.contains(.trailing) {
        style.append(.paddingRight("calc(env(safe-area-inset-right) + \(extra))"))
    }
    return style
}

func safeAreaPaddingStyle(insets: EdgeInsets) -> Style {
    Style {
        .paddingTop("calc(env(safe-area-inset-top) + \(insets.top.cssValue))")
        .paddingLeft("calc(env(safe-area-inset-left) + \(insets.leading.cssValue))")
        .paddingBottom("calc(env(safe-area-inset-bottom) + \(insets.bottom.cssValue))")
        .paddingRight("calc(env(safe-area-inset-right) + \(insets.trailing.cssValue))")
    }
}

extension Edge {
    var cssName: String {
        switch self {
        case .top:
            "top"
        case .leading:
            "leading"
        case .bottom:
            "bottom"
        case .trailing:
            "trailing"
        }
    }
}

extension VerticalEdge {
    var edge: Edge {
        switch self {
        case .top:
            .top
        case .bottom:
            .bottom
        }
    }

    var defaultVerticalAlignment: VerticalAlignment {
        switch self {
        case .top:
            .top
        case .bottom:
            .bottom
        }
    }
}

extension HorizontalEdge {
    var edge: Edge {
        switch self {
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }

    var defaultHorizontalAlignment: HorizontalAlignment {
        switch self {
        case .leading:
            .leading
        case .trailing:
            .trailing
        }
    }
}

extension SafeAreaRegions {
    var cssName: String {
        if self == .all {
            return "all"
        }
        var values: [String] = []
        if contains(.container) {
            values.append("container")
        }
        if contains(.keyboard) {
            values.append("keyboard")
        }
        return values.joined(separator: " ")
    }
}
