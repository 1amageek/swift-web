import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

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

public extension WebUIAttributeMutableHTML {
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

    func onClick(_ handler: @escaping @Sendable () -> Void) -> Self {
        attribute(.onClick(handler))
    }

    func onClick(_ handler: @escaping @Sendable (DOMEvent) -> Void) -> Self {
        attribute(.onClick(handler))
    }

    func onInput(_ handler: @escaping @Sendable (DOMEvent) -> Void) -> Self {
        attribute(.onInput(handler))
    }

    func onChange(_ handler: @escaping @Sendable (DOMEvent) -> Void) -> Self {
        attribute(.onChange(handler))
    }

    func style(_ style: Style) -> Self {
        addingAttributes([styleAttribute(style)])
    }

    func style(@StyleBuilder _ content: () -> Style) -> Self {
        style(content())
    }
}

public extension HTML {
    func padding() -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .class(Space.medium.paddingClassList(edges: .all))
        ]))
    }

    /// Hides this view while preserving its layout space, matching SwiftUI's
    /// `hidden()` (which keeps the view in the layout, unlike removing it).
    /// The `condition` parameter is a web extension over SwiftUI's
    /// argument-less `hidden()`.
    func hidden(_ condition: Bool = true) -> ModifiedContent<Self, HTMLAttributeModifier> {
        condition
            ? modifier(HTMLAttributeModifier([styleAttribute(.visibility("hidden"))]))
            : modifier(HTMLAttributeModifier([]))
    }

    func padding(_ length: Space = .medium) -> ModifiedContent<Self, HTMLAttributeModifier> {
        padding(.all, length)
    }

    func padding(_ length: Length) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(edgePaddingStyle(edges: .all, value: length.cssValue))
        ]))
    }

    func padding(_ edges: Edge.Set, _ length: Space = .medium) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .class(length.paddingClassList(edges: edges))
        ]))
    }

    func padding(_ edges: Edge.Set = .all, _ length: Length?) -> ModifiedContent<Self, HTMLAttributeModifier> {
        if let length {
            return modifier(HTMLAttributeModifier([
                styleAttribute(edgePaddingStyle(edges: edges, value: length.cssValue))
            ]))
        }
        return modifier(HTMLAttributeModifier([
            .class(Space.medium.paddingClassList(edges: edges))
        ]))
    }

    func padding(_ insets: EdgeInsets) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.padding(insets.cssValue))]))
    }

    @available(*, deprecated, message: "Use clipShape(.rect(cornerRadius:))")
    func cornerRadius(_ value: Length) -> ModifiedContent<Self, HTMLAttributeModifier> {
        clipShape(.rect(cornerRadius: value))
    }

    /// Clips this view to `shape`. The shape resolves to a `border-radius`,
    /// and `overflow: hidden` cuts descendants to that rounded box, matching
    /// SwiftUI's clipping semantics rather than only rounding the backdrop.
    /// The stable `swui-clip` hook lets the stylesheet make direct children
    /// inherit the radius, so an inner `.border(...)` follows the clip shape
    /// instead of losing its corners to the clip.
    func clipShape(_ shape: Shape) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            .class("swui-clip"),
            styleAttribute(Style {
                .borderRadius(shape.cornerRadiusValue)
                .overflow("hidden")
            }),
        ]))
    }

    func opacity(_ value: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([styleAttribute(.opacity(trimmedNumber(value)))]))
    }

    func shadow(
        color: Color = Color(cssValue: "rgba(0, 0, 0, 0.33)"),
        radius: Length,
        x: Length = 0,
        y: Length = 0
    ) -> ModifiedContent<Self, HTMLAttributeModifier> {
        modifier(HTMLAttributeModifier([
            styleAttribute(.boxShadow("\(x.cssValue) \(y.cssValue) \(radius.cssValue) \(color.cssValue)"))
        ]))
    }

    func fixedSize() -> ModifiedContent<Self, HTMLAttributeModifier> {
        fixedSize(horizontal: true, vertical: true)
    }

    func fixedSize(horizontal: Bool, vertical: Bool) -> ModifiedContent<Self, HTMLAttributeModifier> {
        var tokens: [String] = []
        if horizontal {
            tokens.append(LayoutClass.hugHorizontal)
        }
        if vertical {
            tokens.append(LayoutClass.hugVertical)
        }
        guard !tokens.isEmpty else {
            return modifier(HTMLAttributeModifier([]))
        }
        return modifier(HTMLAttributeModifier([.class(tokens.joined(separator: " "))]))
    }

    /// Web approximation of SwiftUI's `layoutPriority(_:)`. SwiftUI uses the
    /// priority to order space negotiation, not to make a view greedy; the
    /// closest flexbox analogue is compression resistance, so a positive
    /// priority emits `flex-shrink: 0` (lower-priority siblings shrink first).
    /// The default priority (`0`) and negative priorities emit nothing — a
    /// static stylesheet cannot express relative shrink ordering below the
    /// default.
    func layoutPriority(_ value: Double) -> ModifiedContent<Self, HTMLAttributeModifier> {
        guard value > 0 else {
            return modifier(HTMLAttributeModifier([]))
        }
        return modifier(HTMLAttributeModifier([styleAttribute(.flexShrink("0"))]))
    }
}

public extension HTML {
    func frame(
        width: Double? = nil,
        minWidth: Double? = nil,
        idealWidth: Double? = nil,
        maxWidth: Double? = nil,
        height: Double? = nil,
        minHeight: Double? = nil,
        idealHeight: Double? = nil,
        maxHeight: Double? = nil,
        alignment: Alignment = .center
    ) -> Frame<Self> {
        Frame(
            width: width,
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            height: height,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment
        ) {
            self
        }
    }
}

func pixelValue(_ value: Double) -> String {
    guard value.isFinite else {
        return value.isInfinite ? "100%" : "0px"
    }
    return "\(trimmedNumber(value))px"
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

public struct Frame<Content: HTML>: WebUIAttributeComponent {
    private let width: Double?
    private let minWidth: Double?
    private let idealWidth: Double?
    private let maxWidth: Double?
    private let height: Double?
    private let minHeight: Double?
    private let idealHeight: Double?
    private let maxHeight: Double?
    private let alignment: Alignment
    private let attributes: [HTMLAttribute]
    private let content: Content

    public init(
        width: Double? = nil,
        minWidth: Double? = nil,
        idealWidth: Double? = nil,
        maxWidth: Double? = nil,
        height: Double? = nil,
        minHeight: Double? = nil,
        idealHeight: Double? = nil,
        maxHeight: Double? = nil,
        alignment: Alignment = .center,
        @HTMLBuilder _ content: () -> Content
    ) {
        self.width = width
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.height = height
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.maxHeight = maxHeight
        self.alignment = alignment
        self.attributes = []
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        let layout = frameLayout(
            width: width,
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            height: height,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment
        )
        // The Frame wrapper is a real flex-row container whose sole purpose is to
        // position its child within the requested box, so the row-oriented
        // mapping (justify=main/horizontal, align=cross/vertical) is correct here.
        let style = frameWrapperStyle(layout.style, alignment: alignment)
        Element(
            "div",
            attributes: mergedAttributes(
                class: (["swui-frame"] + layout.classes).joined(separator: " "),
                styles: style,
                extra: attributes
            )
        ) {
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            width: width,
            minWidth: minWidth,
            idealWidth: idealWidth,
            maxWidth: maxWidth,
            height: height,
            minHeight: minHeight,
            idealHeight: idealHeight,
            maxHeight: maxHeight,
            alignment: alignment,
            attributes: self.attributes + attributes,
            content: content
        )
    }

    private init(
        width: Double?,
        minWidth: Double?,
        idealWidth: Double?,
        maxWidth: Double?,
        height: Double?,
        minHeight: Double?,
        idealHeight: Double?,
        maxHeight: Double?,
        alignment: Alignment,
        attributes: [HTMLAttribute],
        content: Content
    ) {
        self.width = width
        self.minWidth = minWidth
        self.idealWidth = idealWidth
        self.maxWidth = maxWidth
        self.height = height
        self.minHeight = minHeight
        self.idealHeight = idealHeight
        self.maxHeight = maxHeight
        self.alignment = alignment
        self.attributes = attributes
        self.content = content
    }
}

func styleAttribute(_ style: Style) -> HTMLAttribute {
    // Route every declaration through the atomic registry so SwiftWeb renderers
    // emit classes instead of inline style attributes. See docs/AtomicStyling.md.
    atom(style)
}

func styleAttribute(@StyleBuilder _ content: () -> Style) -> HTMLAttribute {
    styleAttribute(content())
}

/// Translate `frame(...)` parameters into marker classes and atomic declarations
/// that drive the priority-based layout system.
///
/// The axis intent is resolved through the marker classes so that fill
/// propagation (`:has()`) and parent-axis awareness work in CSS, while explicit
/// lengths remain atomic declarations. A bounded `maxWidth` produces the centered, capped
/// "page" idiom (fill up to the cap, then center).
func frameLayout(
    width: Double?,
    minWidth: Double?,
    idealWidth: Double?,
    maxWidth: Double?,
    height: Double?,
    minHeight: Double?,
    idealHeight: Double?,
    maxHeight: Double?,
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
    if let idealWidth {
        style.append(.custom("--swui-ideal-width", pixelValue(idealWidth)))
    }
    if let idealHeight {
        style.append(.custom("--swui-ideal-height", pixelValue(idealHeight)))
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
    fixed: Double?,
    max: Double?,
    min: Double?,
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
        style.append(.custom(minProperty, min.isInfinite ? "100%" : pixelValue(min)))
    }

    // A required fixed length wins over any fill/hug intent: pin the size and
    // block propagation so the element neither grows nor shrinks.
    if let fixed {
        if fixed.isInfinite {
            classes.append(fillClass)
        } else {
            style.append(.custom(lengthProperty, pixelValue(fixed)))
            classes.append(hugClass)
        }
        return
    }

    guard let max else {
        return
    }

    if max.isInfinite {
        // Unbounded fill: greedily expand on this axis.
        classes.append(fillClass)
    } else {
        // Bounded fill: expand up to the cap, then center within the parent.
        style.append(.custom(maxProperty, pixelValue(max)))
        classes.append(fillClass)
        if centersWhenBounded {
            style.append(.marginInline("auto"))
        }
    }
}
