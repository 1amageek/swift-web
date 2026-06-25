import Foundation
import SwiftHTML
import SwiftWebUI

// Chrome dimensions shared by the catalog shell.
enum CatalogChromeMetrics {
    static let topBarHeight: Double = 54
    static let sidebarWidth: Double = 226
    static let inspectorWidth: Double = 184
}

// MARK: - Top bar

struct CatalogTopBar: Component {
    let colorScheme: Binding<ColorScheme>

    var body: some HTML {
        HStack(spacing: .medium) {
            HStack(spacing: .small) {
                Text("S")
                    .font(Font(size: .px(14), weight: .bold))
                    .foregroundStyle(.white)
                    .frame(width: 26, height: 26)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: 0x65A8FF), Color(hex: 0x1769E0)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        in: .rect(cornerRadius: 7)
                    )
                Text("SwiftWebUI")
                    .font(Font(size: .px(15), weight: .semibold))
                Text("Storyboard")
                    .font(Font(size: .px(11)))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .border(.border, width: 1)
                    .cornerRadius(5)
            }

            // A non-functional visual affordance (no search is wired). Hidden from
            // assistive tech so it is not announced as an operable search.
            HStack(spacing: .small) {
                Text("⌕").foregroundStyle(.secondary)
                Text("Search components").foregroundStyle(.secondary)
                Spacer()
                Text("⌘K")
                    .font(Font(size: .px(11)))
                    .foregroundStyle(.secondary)
            }
            .font(Font(size: .px(13)))
            .padding(.horizontal, 12)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity)
            .background(.surfaceRaised, in: .rect(cornerRadius: 9))
            .accessibilityHidden(true)

            HStack(spacing: .large) {
                topBarLink("Docs", "https://github.com/1amageek/swift-web#readme", muted: true)
                topBarLink("GitHub ↗", "https://github.com/1amageek/swift-web", muted: false)
                HStack(spacing: .xsmall) {
                    colorSchemeButton("Light", value: .light)
                    colorSchemeButton("Dark", value: .dark)
                }
                .padding(3)
                // Filled track only — no hard outline (matches a native segmented control).
                .background(Color.secondary.opacity(0.1), in: .rect(cornerRadius: 8))
                .cornerRadius(8)
            }
        }
        .frame(maxWidth: .infinity, height: CatalogChromeMetrics.topBarHeight)
        .padding(.horizontal, 18)
        .accessibilityRole("banner")
    }

    private func topBarLink(_ title: String, _ href: String, muted: Bool) -> some HTML {
        Link(destination: URL(string: href)!) {
            Text(title)
        }
        .font(Font(size: .px(13.5), weight: .medium))
        .foregroundStyle(muted ? Color.secondary : Color.primary)
    }

    private func colorSchemeButton(_ title: String, value: ColorScheme) -> some HTML {
        Button(action: { colorScheme.wrappedValue = value }) {
            Text(title)
        }
        .buttonStyle(.plain)
        .font(Font(size: .px(13), weight: .medium))
        .foregroundStyle(.primary)
        .padding(.horizontal, 11)
        .frame(height: 30)
        .background(
            Color.surfaceRaised.opacity(colorScheme.wrappedValue == value ? 1 : 0),
            in: .rect(cornerRadius: 6)
        )
    }
}

// MARK: - Sidebar

struct CatalogSidebar: Component {
    let selection: String

    var body: some HTML {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: .large) {
                ForEach(catalogCategories) { category in
                    VStack(alignment: .leading, spacing: .xsmall) {
                        // A section label inside the labelled "navigation" landmark,
                        // not a document heading — keeping it a heading would put an
                        // <h2> before the page <h1> and break the heading outline.
                        Text(category.title)
                            .font(Font(size: .px(11), weight: .bold))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.5)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                        VStack(alignment: .leading, spacing: .xsmall) {
                            ForEach(category.items) { item in
                                CatalogSidebarRow(item: item, selection: selection)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: CatalogChromeMetrics.sidebarWidth, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityRole("navigation")
        .accessibilityLabel("Components")
    }
}

struct CatalogSidebarRow: Component {
    let item: CatalogItem
    let selection: String

    private var isSelected: Bool { selection == item.id }

    var body: some HTML {
        Link(destination: URL(string: item.path)!, .aria("current", isSelected ? "page" : "false")) {
            Text(item.name)
        }
        .font(Font(size: .px(13.5), weight: isSelected ? .semibold : .medium))
        .foregroundStyle(isSelected ? Color.accent : Color.secondary)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color.accent.opacity(isSelected ? 0.12 : 0),
            in: .rect(cornerRadius: 7)
        )
    }
}

// MARK: - Inspector ("On This Page")

struct CatalogInspector: Component {
    let selection: String

    private var showsRenderedHTML: Bool {
        // The Rendered HTML is generated from the demo and shown for every page.
        true
    }

    var body: some HTML {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: .medium) {
                // Label for the "complementary" landmark, not a document heading.
                Text("On This Page")
                    .font(Font(size: .px(11), weight: .bold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .kerning(0.5)
                VStack(alignment: .leading, spacing: .small) {
                    inspectorLink("Preview", anchor: "preview", selected: true)
                    inspectorLink("Usage", anchor: "usage")
                    if showsRenderedHTML {
                        inspectorLink("Rendered HTML", anchor: "rendered-html")
                    }
                    inspectorLink("Properties", anchor: "properties")
                    inspectorLink("Related", anchor: "related")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(width: CatalogChromeMetrics.inspectorWidth, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityRole("complementary")
        .accessibilityLabel("On This Page")
    }

    private func inspectorLink(_ title: String, anchor: String, selected: Bool = false) -> some HTML {
        Link(destination: URL(string: "#\(anchor)")!) {
            Text(title)
        }
        .font(Font(size: .px(13), weight: selected ? .semibold : .regular))
        .foregroundStyle(selected ? Color.accent : Color.secondary)
    }
}
