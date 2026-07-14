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
public struct List<Content: HTML>: AttributeComponent {
    private let attributes: [HTMLAttribute]
    private let content: Content
    private let isSemanticList: Bool
    @Environment({ $0.listStyle }) private var listStyle: ListStyleKind

    public init(
        _ attributes: HTMLAttribute...,
        @HTMLBuilder content: () -> Content
    ) {
        self.attributes = attributes
        self.content = content()
        // Builder children carry no per-row elements the runtime can mark as
        // listitems, so the container stays a visual list: emitting
        // `role="list"` without `role="listitem"` children would be invalid ARIA.
        self.isSemanticList = false
    }

    @HTMLBuilder
    public var body: some HTML {
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
            content
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(attributes: self.attributes + attributes, content: content, isSemanticList: isSemanticList)
    }

    private init(attributes: [HTMLAttribute], content: Content, isSemanticList: Bool) {
        self.attributes = attributes
        self.content = content
        self.isSemanticList = isSemanticList
    }
}

public extension List {
    /// Creates a list from a collection of identifiable data, mirroring
    /// SwiftUI's `List(_:rowContent:)`.
    init<Data: RandomAccessCollection & Sendable, RowContent: HTML>(
        _ data: Data,
        @HTMLBuilder rowContent: @escaping @Sendable (Data.Element) -> RowContent
    ) where Data.Element: Identifiable & Sendable, Content == ForEach<Data, Data.Element.ID, ListRowContainer<RowContent>> {
        self.init(
            attributes: [],
            content: ForEach(data) { element in
                ListRowContainer { rowContent(element) }
            },
            isSemanticList: true
        )
    }

    /// Creates a list from a collection keyed by `id`, mirroring SwiftUI's
    /// `List(_:id:rowContent:)`.
    init<Data: RandomAccessCollection & Sendable, ID: Hashable & Sendable, RowContent: HTML>(
        _ data: Data,
        id: @escaping @Sendable (Data.Element) -> ID,
        @HTMLBuilder rowContent: @escaping @Sendable (Data.Element) -> RowContent
    ) where Data.Element: Sendable, Content == ForEach<Data, ID, ListRowContainer<RowContent>> {
        self.init(
            attributes: [],
            content: ForEach(data, id: id) { element in
                ListRowContainer { rowContent(element) }
            },
            isSemanticList: true
        )
    }
}

/// The semantic row box the data-driven `List` initializers wrap each element
/// in. Builder-form lists style their children directly and never emit it.
public struct ListRowContainer<Content: HTML>: Component {
    private let content: Content

    init(@HTMLBuilder content: () -> Content) {
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: "swui-list-row",
                extra: [.role("listitem")]
            )
        ) {
            content
        }
    }
}
