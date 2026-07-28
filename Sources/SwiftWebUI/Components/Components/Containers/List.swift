import SwiftWebUITheme
import SwiftHTML
import SwiftWebStyle

/// A container of rows, mirroring SwiftUI's `List`.
///
/// Every direct child is a row, exactly like SwiftUI: the row chrome (layout,
/// separators, typography) applies to the list's children through the
/// stylesheet, so `List { Text("a"); Text("b") }` needs no row wrapper type.
/// The data-driven initializers wrap each element in a semantic row
/// (`role="listitem"`), giving collection lists full list semantics.
public struct List: AttributeComponent {
    private let attributes: [HTMLAttribute]
    private let childContent: ComponentContent
    private let isSemanticList: Bool
    @Environment({ $0.listStyle }) private var listStyle: ListStyleKind

    public init<Content: Component>(
        _ attributes: HTMLAttribute...,
        @ComponentBuilder content: () -> Content
    ) {
        self.attributes = attributes
        self.childContent = HTMLBuilder.buildExpression(content())
        // Builder children carry no per-row elements the runtime can mark as
        // listitems, so the container stays a visual list: emitting
        // `role="list"` without `role="listitem"` children would be invalid ARIA.
        self.isSemanticList = false
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName(
                    "swui-list",
                    listStyle.className,
                    LayoutClass.fillHorizontal,
                    Space.small.gapClassName.rawValue
                ),
                extra: (isSemanticList ? [.role("list")] : []) + attributes
            )
        ) {
            childContent
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(attributes: self.attributes + attributes, content: childContent, isSemanticList: isSemanticList)
    }

    private init(attributes: [HTMLAttribute], content: ComponentContent, isSemanticList: Bool) {
        self.attributes = attributes
        self.childContent = content
        self.isSemanticList = isSemanticList
    }
}

public extension List {
    /// Creates a list from a collection of identifiable data, mirroring
    /// SwiftUI's `List(_:rowContent:)`.
    init<Data: RandomAccessCollection & Sendable, RowContent: Component>(
        _ data: Data,
        @ComponentBuilder rowContent: @escaping @Sendable (Data.Element) -> RowContent
    ) where Data.Element: Identifiable & Sendable, Data.Element.ID: Sendable {
        let rows = ForEach(data) { element in
            ListRowContainer { rowContent(element) }
        }
        self.init(
            attributes: [],
            content: HTMLBuilder.buildExpression(rows),
            isSemanticList: true
        )
    }

    /// Creates a list from a collection keyed by `id`, mirroring SwiftUI's
    /// `List(_:id:rowContent:)`.
    init<Data: RandomAccessCollection & Sendable, ID: Hashable & Sendable, RowContent: Component>(
        _ data: Data,
        id: @escaping @Sendable (Data.Element) -> ID,
        @ComponentBuilder rowContent: @escaping @Sendable (Data.Element) -> RowContent
    ) where Data.Element: Sendable {
        let rows = ForEach(data, id: id) { element in
            ListRowContainer { rowContent(element) }
        }
        self.init(
            attributes: [],
            content: HTMLBuilder.buildExpression(rows),
            isSemanticList: true
        )
    }
}

/// The semantic row box the data-driven `List` initializers wrap each element
/// in. Builder-form lists style their children directly and never emit it.
public struct ListRowContainer<Content: Component>: Component {
    private let childContent: Content

    init(@HTMLBuilder content: () -> Content) {
        self.childContent = content()
    }

    @ComponentBuilder
    public var content: some Component {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-list-row",
                extra: [.role("listitem")]
            )
        ) {
            childContent
        }
    }
}
