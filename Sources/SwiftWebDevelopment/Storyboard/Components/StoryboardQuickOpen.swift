#if !hasFeature(Embedded)
import Foundation
#endif
import SwiftHTML
import SwiftWebUI

// SwiftHTML supplies the Embedded spelling; Foundation owns the standard one.
#if hasFeature(Embedded)
private typealias StoryboardCharacterSet = SwiftHTML.CharacterSet
#else
private typealias StoryboardCharacterSet = Foundation.CharacterSet
#endif

/// The catalog's quick-open search: a real, working ⌘K palette.
///
/// The trigger renders in the top bar; opening it filters the whole catalog by
/// name, code, and summary. Result rows are semantic anchors, so selection
/// rides the same enhanced same-origin navigation as every other catalog link.
/// The chrome script forwards ⌘K / Ctrl+K to the trigger and Escape to the
/// close control.
public struct StoryboardQuickOpen: ClientComponent {
    @State private var isOpen = false
    @State private var query = ""

    public init() {}

    public var content: some Component {
        div(.class("swui-storyboard-quickopen swui-fill-h")) {
            Button {
                isOpen = true
            } label: {
                HStack(spacing: .small) {
                    Text("⌕").as(.span).foregroundStyle(.secondary)
                    Text("Search components").as(.span).foregroundStyle(.secondary)
                    Spacer()
                    Text("⌘K").as(.span)
                        .font(Font(size: .px(11)))
                        .foregroundStyle(.secondary)
                }
                .font(Font(size: .px(13)))
                .frame(maxWidth: .infinity)
            }
            .data("quick-open-trigger", "true")
            .class("swui-storyboard-search-trigger")
            .buttonStyle(.plain)

            if isOpen {
                quickOpenOverlay()
            }
        }
    }

    @HTMLBuilder
    private func quickOpenOverlay() -> some Component {
        div(.class("swui-storyboard-quickopen-overlay")) {
            Button {
                isOpen = false
                query = ""
            } label: {
                Text("Close search").as(.span)
            }
            .data("quick-open-close", "true")
            .class("swui-storyboard-quickopen-backdrop")
            .buttonStyle(.plain)
            .accessibilityLabel("Close search")

            div(.class("swui-storyboard-quickopen-panel swui-material swui-material-bar")) {
                TextField("Search components", text: $query, prompt: Text("Search components"))
                    .data("quick-open-input", "true")
                    .class("swui-storyboard-quickopen-field")
                div(.class("swui-storyboard-quickopen-list")) {
                    ForEach(matches) { item in
                        quickOpenRow(item)
                    }
                    if matches.isEmpty {
                        Text("No components match “\(query)”")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .padding(.medium)
                    }
                }
            }
        }
    }

    @HTMLBuilder
    private func quickOpenRow(_ item: CatalogItem) -> some Component {
        Link(destination: URL(string: item.path)!) {
            VStack(alignment: .leading, spacing: .xsmall) {
                HStack(spacing: .small) {
                    Text(item.name).as(.span)
                        .fontWeight(.semibold)
                    Text(item.code).as(.span)
                        .font(Font(size: .px(11.5), design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Text(item.summary).as(.span)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .class("swui-storyboard-quickopen-row")
        .foregroundStyle(.primary)
    }

    private var matches: [CatalogItem] {
        let needle = query.trimmingCharacters(in: StoryboardCharacterSet.whitespaces).lowercased()
        let allItems = catalogCategories.flatMap { category in category.items }
        guard !needle.isEmpty else {
            return Array(allItems.prefix(9))
        }
        return Array(
            allItems.filter { item in
                storyboardContains(item.name.lowercased(), needle)
                    || storyboardContains(item.code.lowercased(), needle)
                    || storyboardContains(item.summary.lowercased(), needle)
            }
            .prefix(12)
        )
    }
}
