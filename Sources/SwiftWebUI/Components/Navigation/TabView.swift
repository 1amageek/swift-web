import SwiftHTML

/// A container that pages between mutually exclusive `Tab` children, mirroring
/// SwiftUI `TabView`.
///
/// The tab bar and panels lower together: each `Tab` renders a hidden radio (the
/// tab button) plus its panel, and CSS reveals the active panel. `TabView`
/// establishes the shared radio group and a single delegated change handler that
/// keeps the selection binding in sync, so switching tabs works without a client
/// runtime while server-side state stays consistent. The binding's current value
/// chooses the initially selected tab.
public struct TabView<Content: HTML>: WebUIAttributeComponent {
    private let selection: Binding<String>
    private let attributes: [HTMLAttribute]
    private let content: Content
    // The call-site source location gives every `TabView` a stable, unique radio
    // group `name` so multiple tab views on one page do not share a group. This
    // is the same identity `@State` uses, so it survives re-renders.
    private let sourceFileID: String
    private let sourceLine: Int
    private let sourceColumn: Int

    @Environment(\.isEnabled) private var isEnabled: Bool
    @Environment(\.tabViewStyle) private var tabViewStyle: TabViewStyleKind

    public init(
        selection: Binding<String>,
        _ attributes: HTMLAttribute...,
        fileID: String = #fileID,
        line: Int = #line,
        column: Int = #column,
        @HTMLBuilder content: () -> Content
    ) {
        self.selection = selection
        self.attributes = attributes
        self.content = content()
        self.sourceFileID = fileID
        self.sourceLine = line
        self.sourceColumn = column
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(
            "div",
            attributes: mergedAttributes(
                class: controlClassName("swui-tabview", tabViewStyle.className, LayoutClass.fillHorizontal),
                extra: tabViewAttributes
            )
        ) {
            content
                .environment(\.tabSelection, selection.wrappedValue)
                .environment(\.tabGroupName, groupName)
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(
            selection: selection,
            attributes: self.attributes + attributes,
            content: content,
            sourceFileID: sourceFileID,
            sourceLine: sourceLine,
            sourceColumn: sourceColumn
        )
    }

    private init(
        selection: Binding<String>,
        attributes: [HTMLAttribute],
        content: Content,
        sourceFileID: String,
        sourceLine: Int,
        sourceColumn: Int
    ) {
        self.selection = selection
        self.attributes = attributes
        self.content = content
        self.sourceFileID = sourceFileID
        self.sourceLine = sourceLine
        self.sourceColumn = sourceColumn
    }

    // A single delegated change handler on the tab container: a child radio's
    // change event bubbles here, and `event.value` carries the fired radio's
    // value, so one handler drives the whole tab group.
    private var tabViewAttributes: [HTMLAttribute] {
        let selection = self.selection
        var result: [HTMLAttribute] = [
            HTMLAttribute("role", "tablist"),
            .onChange { event in
                if let value = event.value {
                    selection.wrappedValue = value
                }
            },
        ]
        if !isEnabled {
            result.append(.aria("disabled", "true"))
        }
        result.append(contentsOf: attributes)
        return result
    }

    // A stable radio-group `name` derived from the call site so the tabs are
    // mutually exclusive natively without colliding with other tab views.
    private var groupName: String {
        let raw = "\(sourceFileID)-\(sourceLine)-\(sourceColumn)"
        let sanitized = String(raw.map { character in
            character.isLetter || character.isNumber ? character : "-"
        })
        return "swui-tabview-\(sanitized)"
    }
}
