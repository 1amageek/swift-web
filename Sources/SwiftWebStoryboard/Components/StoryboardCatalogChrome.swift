import Foundation
import SwiftHTML
import SwiftWebUI

struct CatalogTopBar: Component {
    let theme: Binding<Theme>

    var body: some HTML {
        HStack(spacing: .medium) {
            HStack(spacing: .small) {
                div(.class("storyboard-mark")) {
                    "S"
                }
                div(.class("storyboard-product-title")) {
                    "SwiftWebUI"
                }
                span(.class("storyboard-product-badge")) {
                    "Storyboard"
                }
            }
            .class("storyboard-topbar-title")

            div(.class("storyboard-search"), .role("search")) {
                span(.class("storyboard-search-icon"), .aria("hidden", "true")) {
                    "⌕"
                }
                span {
                    "Search components"
                }
                span(.class("storyboard-search-shortcut")) {
                    "⌘K"
                }
            }

            HStack(spacing: .large) {
                Element("a", attributes: [.href("#"), .class("storyboard-topbar-link is-muted")]) {
                    "Docs"
                }
                Element("a", attributes: [.href("#"), .class("storyboard-topbar-link")]) {
                    "GitHub ↗"
                }
                HStack(spacing: .xsmall) {
                    themeButton("Light", value: .light)
                    themeButton("Dark", value: .dark)
                }
                .class("storyboard-theme-switcher")
            }
            .class("storyboard-topbar-actions")
        }
        .class("storyboard-topbar")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func themeButton(_ title: String, value: Theme) -> some HTML {
        Button(title) {
            theme.wrappedValue = value
        }
        .class("storyboard-theme-button\(theme.wrappedValue == value ? " is-selected" : "")")
    }
}

struct CatalogSidebar: Component {
    let selection: String

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            ForEach(catalogCategories) { category in
                VStack(alignment: .leading, spacing: .xsmall) {
                    Text(category.title, as: .small, tone: .muted)
                        .class("storyboard-sidebar-section-title")
                    VStack(alignment: .leading, spacing: .xsmall) {
                        ForEach(category.items) { item in
                            CatalogSidebarRow(item: item, selection: selection)
                        }
                    }
                    .class("storyboard-sidebar-section-items")
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .class("storyboard-sidebar-section")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .class("storyboard-sidebar")
        .frame(width: 226, alignment: .leading)
    }
}

struct CatalogSidebarRow: Component {
    let item: CatalogItem
    let selection: String

    var body: some HTML {
        Element("a", attributes: linkAttributes) {
            item.name
        }
    }

    private var linkAttributes: [HTMLAttribute] {
        var attributes: [HTMLAttribute] = [
            .href(item.path),
            .class("storyboard-sidebar-link\(selection == item.id ? " is-selected" : "")"),
        ]
        if selection == item.id {
            attributes.append(.aria("current", "page"))
        }
        return attributes
    }
}

struct CatalogInspector: Component {
    let selection: String

    var body: some HTML {
        VStack(alignment: .leading, spacing: .medium) {
            div(.class("storyboard-inspector-title")) {
                "On This Page"
            }
            VStack(alignment: .leading, spacing: .medium) {
                inspectorLink("Preview", selected: true)
                inspectorLink("Usage")
                if showsRenderedHTML {
                    inspectorLink("Rendered HTML")
                }
                inspectorLink("Properties")
                inspectorLink("Related")
            }
            .class("storyboard-inspector-nav")
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .class("storyboard-inspector")
        .frame(width: 184, alignment: .leading)
    }

    private var showsRenderedHTML: Bool {
        !["gridsystem", "spacing", "alignment", "responsive", "safearea"].contains(selection)
    }

    private func inspectorLink(_ title: String, selected: Bool = false) -> some HTML {
        span(.class("storyboard-inspector-link\(selected ? " is-selected" : "")")) {
            title
        }
    }
}
