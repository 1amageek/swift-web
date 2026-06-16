import SwiftHTML

public protocol WebUIAttributeMutableHTML: HTML {
    func addingAttributes(_ attributes: [HTMLAttribute]) -> Self
}

public protocol WebUIAttributeComponent: Component, WebUIAttributeMutableHTML {}

extension ModifiedContent: WebUIAttributeMutableHTML where Content: WebUIAttributeMutableHTML {
    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        ModifiedContent(
            content: content.addingAttributes(attributes),
            modifier: modifier
        )
    }
}

public enum WebUILength: Sendable, Equatable, ExpressibleByStringLiteral, ExpressibleByIntegerLiteral {
    case css(String)
    case infinity

    public init(stringLiteral value: String) {
        self = .css(value)
    }

    public init(integerLiteral value: Int) {
        self = .css("\(value)px")
    }
}

public struct Alignment: Sendable, Equatable {
    public var horizontal: HorizontalAlignment
    public var vertical: VerticalAlignment

    public init(horizontal: HorizontalAlignment, vertical: VerticalAlignment) {
        self.horizontal = horizontal
        self.vertical = vertical
    }

    public static let topLeading = Alignment(horizontal: .leading, vertical: .top)
    public static let top = Alignment(horizontal: .center, vertical: .top)
    public static let topTrailing = Alignment(horizontal: .trailing, vertical: .top)
    public static let leading = Alignment(horizontal: .leading, vertical: .center)
    public static let center = Alignment(horizontal: .center, vertical: .center)
    public static let trailing = Alignment(horizontal: .trailing, vertical: .center)
    public static let bottomLeading = Alignment(horizontal: .leading, vertical: .bottom)
    public static let bottom = Alignment(horizontal: .center, vertical: .bottom)
    public static let bottomTrailing = Alignment(horizontal: .trailing, vertical: .bottom)

    var justifyContent: String {
        horizontal.rawValue
    }

    var alignItems: String {
        vertical.rawValue
    }

    var textAlign: String {
        horizontal.textAlign
    }
}

public extension WebUIAttributeComponent {
    func attribute(_ attribute: HTMLAttribute) -> Self {
        addingAttributes([attribute])
    }

    func attributes(_ attributes: HTMLAttribute...) -> Self {
        addingAttributes(attributes)
    }

    func id(_ value: String) -> Self {
        attribute(.id(value))
    }

    func `class`(_ value: String) -> Self {
        attribute(.class(value))
    }

    func data(_ name: String, _ value: String) -> Self {
        attribute(.data(name, value))
    }

    func aria(_ name: String, _ value: String) -> Self {
        attribute(.aria(name, value))
    }

    func role(_ value: String) -> Self {
        attribute(.role(value))
    }

    func title(_ value: String) -> Self {
        attribute(.title(value))
    }

    func name(_ value: String) -> Self {
        attribute(.name(value))
    }

    func value(_ value: String) -> Self {
        attribute(.value(value))
    }

    func value(_ value: Int) -> Self {
        attribute(.value(value))
    }

    func hidden(_ condition: Bool = true) -> Self {
        condition ? attribute(.hidden) : self
    }

    func onClick(_ handler: @escaping () -> Void) -> Self {
        attribute(.onClick(handler))
    }

    func onClick(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onClick(handler))
    }

    func onInput(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onInput(handler))
    }

    func onChange(_ handler: @escaping (DOMEvent) -> Void) -> Self {
        attribute(.onChange(handler))
    }

    func padding(_ length: Space = .medium) -> Self {
        style(.padding(length.rawValue))
    }

    func padding(_ edges: Edge.Set, _ length: Space = .medium) -> Self {
        style(edgePaddingStyle(edges: edges, value: length.rawValue))
    }

    func padding(_ edges: Edge.Set, _ value: String) -> Self {
        style(edgePaddingStyle(edges: edges, value: value))
    }

    func padding(_ value: String) -> Self {
        style(.padding(value))
    }

    @available(*, deprecated, renamed: "foregroundStyle")
    func foregroundColor(_ value: String) -> Self {
        style(.color(value))
    }

    func background(_ value: String) -> Self {
        style(.background(value))
    }

    func cornerRadius(_ value: String) -> Self {
        style(.borderRadius(value))
    }

    func style(_ style: Style) -> Self {
        addingAttributes([styleAttribute(style)])
    }

    func style(@StyleBuilder _ content: () -> Style) -> Self {
        style(content())
    }

    /// Pin the element to its intrinsic size so it neither expands nor blocks
    /// parent fill propagation. Mirrors SwiftUI `fixedSize()`.
    func fixedSize() -> Self {
        fixedSize(horizontal: true, vertical: true)
    }

    /// Pin the element to its intrinsic size along the selected axes.
    func fixedSize(horizontal: Bool, vertical: Bool) -> Self {
        var tokens: [String] = []
        if horizontal {
            tokens.append(LayoutClass.hugHorizontal)
        }
        if vertical {
            tokens.append(LayoutClass.hugVertical)
        }
        guard !tokens.isEmpty else {
            return self
        }
        return addingAttributes([.class(tokens.joined(separator: " "))])
    }

    /// Relative growth weight among expanding siblings, mirroring SwiftUI
    /// `layoutPriority(_:)`. Higher values claim more of the available space on
    /// the parent's main axis.
    func layoutPriority(_ value: Double) -> Self {
        style(.custom("flex-grow", trimmedNumber(value)))
    }

    func frame(
        width: WebUILength? = nil,
        minWidth: WebUILength? = nil,
        maxWidth: WebUILength? = nil,
        height: WebUILength? = nil,
        minHeight: WebUILength? = nil,
        maxHeight: WebUILength? = nil,
        alignment: Alignment = .center
    ) -> Self {
        let layout = frameLayout(
            width: width,
            minWidth: minWidth,
            maxWidth: maxWidth,
            height: height,
            minHeight: minHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )
        var attributes: [HTMLAttribute] = []
        if !layout.classes.isEmpty {
            attributes.append(.class(layout.classes.joined(separator: " ")))
        }
        var style = layout.style
        // Axis-neutral content alignment for the element itself. Flex children
        // are positioned by the element's own `alignment:`; `text-align` aligns
        // inline/text content of a leaf within an expanded frame.
        style.append(.textAlign(alignment.textAlign))
        attributes.append(styleAttribute(style))
        return addingAttributes(attributes)
    }
}

func trimmedNumber(_ value: Double) -> String {
    if value == value.rounded() {
        return String(Int(value))
    }
    return String(value)
}

/// Layer the full row-oriented flex alignment onto a sizing style. Used by the
/// `Frame` wrapper, which positions its child within the requested box.
func frameWrapperStyle(_ base: Style, alignment: Alignment) -> Style {
    var style = base
    style.append(.justifyContent(alignment.justifyContent))
    style.append(.alignItems(alignment.alignItems))
    style.append(.textAlign(alignment.textAlign))
    return style
}

func edgePaddingStyle(edges: Edge.Set, value: String) -> Style {
    if edges == .all {
        return .padding(value)
    }

    var style = Style()
    if edges.contains(.top) {
        style.append(.paddingTop(value))
    }
    if edges.contains(.leading) {
        style.append(.paddingLeft(value))
    }
    if edges.contains(.bottom) {
        style.append(.paddingBottom(value))
    }
    if edges.contains(.trailing) {
        style.append(.paddingRight(value))
    }
    return style
}

public struct Frame<Content: HTML>: Component {
    private let width: WebUILength?
    private let minWidth: WebUILength?
    private let maxWidth: WebUILength?
    private let height: WebUILength?
    private let minHeight: WebUILength?
    private let maxHeight: WebUILength?
    private let alignment: Alignment
    private let content: Content

    public init(
        width: WebUILength? = nil,
        minWidth: WebUILength? = nil,
        maxWidth: WebUILength? = nil,
        height: WebUILength? = nil,
        minHeight: WebUILength? = nil,
        maxHeight: WebUILength? = nil,
        alignment: Alignment = .center,
        @HTMLBuilder _ content: () -> Content
    ) {
        self.width = width
        self.minWidth = minWidth
        self.maxWidth = maxWidth
        self.height = height
        self.minHeight = minHeight
        self.maxHeight = maxHeight
        self.alignment = alignment
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        let layout = frameLayout(
            width: width,
            minWidth: minWidth,
            maxWidth: maxWidth,
            height: height,
            minHeight: minHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )
        // The Frame wrapper is a real flex-row container whose sole purpose is to
        // position its child within the requested box, so the row-oriented
        // mapping (justify=main/horizontal, align=cross/vertical) is correct here.
        let style = frameWrapperStyle(layout.style, alignment: alignment)
        Element(
            "div",
            attributes: [
                .class((["swui-frame"] + layout.classes).joined(separator: " ")),
                styleAttribute(style),
            ]
        ) {
            content
        }
    }
}

public extension HTML {
    func frame(
        width: WebUILength? = nil,
        minWidth: WebUILength? = nil,
        maxWidth: WebUILength? = nil,
        height: WebUILength? = nil,
        minHeight: WebUILength? = nil,
        maxHeight: WebUILength? = nil,
        alignment: Alignment = .center
    ) -> Frame<Self> {
        Frame(
            width: width,
            minWidth: minWidth,
            maxWidth: maxWidth,
            height: height,
            minHeight: minHeight,
            maxHeight: maxHeight,
            alignment: alignment
        ) {
            self
        }
    }
}

func styleAttribute(_ style: Style) -> HTMLAttribute {
    .style(style)
}

func styleAttribute(@StyleBuilder _ content: () -> Style) -> HTMLAttribute {
    styleAttribute(content())
}

/// Translate `frame(...)` parameters into the marker classes and inline styles
/// that drive the priority-based layout system.
///
/// The axis intent is resolved through the marker classes so that fill
/// propagation (`:has()`) and parent-axis awareness work in CSS, while explicit
/// lengths remain inline. A bounded `maxWidth` produces the centered, capped
/// "page" idiom (fill up to the cap, then center).
func frameLayout(
    width: WebUILength?,
    minWidth: WebUILength?,
    maxWidth: WebUILength?,
    height: WebUILength?,
    minHeight: WebUILength?,
    maxHeight: WebUILength?,
    alignment: Alignment
) -> (classes: [String], style: Style) {
    var classes: [String] = []
    // Sizing only. Child arrangement (justify-content/align-items) is owned by
    // the element type (VStack/HStack set their own axes); emitting it here
    // would invert the axis on a column and collide with the element's own
    // declaration. Alignment is layered on by the caller: the in-place modifier
    // adds `text-align` (axis-neutral), while the `Frame` wrapper adds the full
    // row-oriented flex alignment because it genuinely positions its child.
    var style = Style {
        .boxSizing("border-box")
    }

    resolveAxis(
        fixed: width,
        max: maxWidth,
        min: minWidth,
        fillClass: LayoutClass.fillHorizontal,
        hugClass: LayoutClass.hugHorizontal,
        lengthProperty: "width",
        minProperty: "min-width",
        maxProperty: "max-width",
        centersWhenBounded: alignment.horizontal == .center,
        classes: &classes,
        style: &style
    )
    resolveAxis(
        fixed: height,
        max: maxHeight,
        min: minHeight,
        fillClass: LayoutClass.fillVertical,
        hugClass: LayoutClass.hugVertical,
        lengthProperty: "height",
        minProperty: "min-height",
        maxProperty: "max-height",
        centersWhenBounded: false,
        classes: &classes,
        style: &style
    )

    return (classes, style)
}

private func resolveAxis(
    fixed: WebUILength?,
    max: WebUILength?,
    min: WebUILength?,
    fillClass: String,
    hugClass: String,
    lengthProperty: String,
    minProperty: String,
    maxProperty: String,
    centersWhenBounded: Bool,
    classes: inout [String],
    style: inout Style
) {
    if let min {
        switch min {
        case .css(let value):
            style.append(.custom(minProperty, value))
        case .infinity:
            style.append(.custom(minProperty, "100%"))
        }
    }

    // A required fixed length wins over any fill/hug intent: pin the size and
    // block propagation so the element neither grows nor shrinks.
    if let fixed {
        switch fixed {
        case .css(let value):
            style.append(.custom(lengthProperty, value))
            classes.append(hugClass)
            return
        case .infinity:
            classes.append(fillClass)
            return
        }
    }

    guard let max else {
        return
    }

    switch max {
    case .infinity:
        // Unbounded fill: greedily expand on this axis.
        classes.append(fillClass)
    case .css(let value):
        // Bounded fill: expand up to the cap, then center within the parent.
        style.append(.custom(maxProperty, value))
        classes.append(fillClass)
        if centersWhenBounded {
            style.append(.custom("margin-inline", "auto"))
        }
    }
}
