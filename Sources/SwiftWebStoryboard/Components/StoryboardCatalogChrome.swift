import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Chrome: top bar

/// The sticky global control bar spanning all three panes. The theme and
/// style-system controls drive the catalog's @State; the enclosing scope
/// re-applies `.environment` on every change, so the whole catalog rethemes
/// live. The bar composes the `.bar` material, dogfooding the style system it
/// switches.
struct CatalogTopBar: Component {
    let theme: Binding<Theme>
    let styleID: Binding<String>

    var body: some HTML {
        HStack(spacing: .large) {
            HStack(spacing: .small) {
                Badge("SwiftWebUI")
                Text("Component Storyboard", as: .strong)
            }

            Spacer()

            HStack(spacing: .large) {
                HStack(spacing: .xsmall) {
                    ThemeSwitcher(selection: theme, themes: [.light, .dark, .system])
                }
                HStack(spacing: .xsmall) {
                    Picker("Style", selection: styleID) {
                        PickerOption("SwiftWeb", value: "swift-web")
                        PickerOption("Material", value: "material")
                        PickerOption("Liquid Glass", value: "liquid-glass")
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "12px 20px")
        .background(.bar, in: .rect(cornerRadius: 0))
        .style {
            .custom("position", "sticky")
            .custom("top", "0")
            .custom("z-index", "40")
            .custom("border-bottom", "1px solid var(--swui-border)")
        }
    }
}

// MARK: - Chrome: sidebar

/// The component picker. Categories are headings; each item links to its
/// canonical Storyboard path so direct URLs, refreshes, and sidebar navigation
/// all resolve through the same page route.
struct CatalogSidebar: Component {
    let selection: String

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            ForEach(catalogCategories) { category in
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text(category.title, as: .small, tone: .muted)
                        .style {
                            .custom("text-transform", "uppercase")
                            .custom("letter-spacing", "0.04em")
                            .fontWeight("600")
                        }
                    ForEach(category.items) { item in
                        CatalogSidebarRow(item: item, selection: selection)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: "168px", alignment: .leading)
        .padding(.all, "18px 14px")
        .style {
            .custom("flex", "0 0 168px")
            .height("100%")
            .custom("overflow-y", "auto")
            .custom("border-right", "1px solid var(--swui-border)")
        }
    }
}

/// One sidebar row: a semantic link whose selected state tints the label and
/// raises a subtle accent background.
struct CatalogSidebarRow: Component {
    let item: CatalogItem
    let selection: String

    var body: some HTML {
        Element("a", attributes: linkAttributes) {
            Text(item.name, as: .span)
        }
    }

    private var linkAttributes: [HTMLAttribute] {
        let selected = selection == item.id
        var attributes: [HTMLAttribute] = [
            .href(item.path),
            .class("storyboard-sidebar-link\(selected ? " is-selected" : "")"),
        ]
        if selected {
            attributes.append(HTMLAttribute("aria-current", "page"))
        }
        return attributes
    }
}

// MARK: - Chrome: inspector

/// The right pane. It shows the selected component's API signature and summary,
/// then the sibling components in the same section for quick context.
struct CatalogInspector: Component {
    let selection: String

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            inspectorMetadata()
            inspectorSection()
        }
        .frame(width: "200px", alignment: .leading)
        .padding(.all, "20px 18px")
        .style {
            .custom("flex", "0 0 200px")
            .height("100%")
            .custom("overflow-y", "auto")
            .custom("border-left", "1px solid var(--swui-border)")
        }
    }

    @HTMLBuilder
    private func inspectorMetadata() -> some HTML {
        if let item = catalogItem(for: selection) {
            VStack(alignment: .leading, spacing: .large) {
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("API", as: .small, tone: .muted)
                    CatalogCodeChip(item.code)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: .xsmall) {
                    Text("Summary", as: .small, tone: .muted)
                    Text(item.summary, tone: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func inspectorSection() -> some HTML {
        if let category = catalogCategory(for: selection) {
            VStack(alignment: .leading, spacing: .xsmall) {
                Text("In this section", as: .small, tone: .muted)
                ForEach(category.items) { item in
                    inspectorSectionRow(item)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    @HTMLBuilder
    private func inspectorSectionRow(_ item: CatalogItem) -> some HTML {
        if item.id == selection {
            Text(item.name, as: .strong)
        } else {
            Text(item.name, tone: .muted)
        }
    }
}
