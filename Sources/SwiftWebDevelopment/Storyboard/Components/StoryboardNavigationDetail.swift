import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Navigation & tabs

struct NavigationDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>

    private var state: [String: String] { ui.wrappedValue }

    var body: some HTML {
        switch selection {
        case "tabview":
            tabViewDemo()
        case "navigationlink":
            navigationLinkDemo()
        case "searchable":
            List {
                Text("Inbox")
                Text("Drafts")
                Text("Sent")
            }
            .searchable(text: ui.string("searchable.query"), prompt: searchPrompt)
        default:
            navigationStackDemo()
        }
    }

    @HTMLBuilder
    private func tabViewDemo() -> some HTML {
        if state.controlFlag("tabview", "icons") {
            TabView(selection: ui.string("tabview.tab")) {
                Tab("Summary", systemImage: "doc.text", value: "summary") { tabPanel("Summary") }
                Tab("Activity", systemImage: "chart.bar", value: "activity") { tabPanel("Activity") }
                Tab("Settings", systemImage: "gear", value: "settings") { tabPanel("Settings") }
            }
        } else {
            TabView(selection: ui.string("tabview.tab")) {
                Tab("Summary", value: "summary") { tabPanel("Summary") }
                Tab("Activity", value: "activity") { tabPanel("Activity") }
                Tab("Settings", value: "settings") { tabPanel("Settings") }
            }
        }
    }

    private func tabPanel(_ name: String) -> some HTML {
        Text("\(name) panel content.").foregroundStyle(.secondary)
    }

    @HTMLBuilder
    private func navigationLinkDemo() -> some HTML {
        let url = URL(string: "#overview")!
        navigationLinkInner(url: url, icon: state.controlFlag("navigationlink", "icon"), styled: state.control("navigationlink", "style") == "bordered")
            .disabled(state.controlFlag("navigationlink", "disabled"))
    }

    @HTMLBuilder
    private func navigationLinkInner(url: URL, icon: Bool, styled: Bool) -> some HTML {
        if styled {
            navigationLinkBase(url: url, icon: icon).buttonStyle(.bordered)
        } else {
            navigationLinkBase(url: url, icon: icon)
        }
    }

    @HTMLBuilder
    private func navigationLinkBase(url: URL, icon: Bool) -> some HTML {
        if icon {
            NavigationLink(destination: url) { Label(linkLabel, systemImage: "photo") }
        } else {
            NavigationLink(linkLabel, destination: url)
        }
    }

    @HTMLBuilder
    private func navigationStackDemo() -> some HTML {
        NavigationStack {
            VStack(alignment: .leading, spacing: .small) {
                if state.controlFlag("navigationstack", "icons") {
                    NavigationLink(destination: URL(string: "#overview")!) { Label("Overview", systemImage: "doc.text") }
                    NavigationLink(destination: URL(string: "#components")!) { Label("Components", systemImage: "photo") }
                    NavigationLink(destination: URL(string: "#tokens")!) { Label("Tokens", systemImage: "chart.bar") }
                } else {
                    NavigationLink("Overview", destination: URL(string: "#overview")!)
                    NavigationLink("Components", destination: URL(string: "#components")!)
                    NavigationLink("Tokens", destination: URL(string: "#tokens")!)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(state.control("navigationstack", "title"))
    }

    private var linkLabel: String {
        let value = state.control("navigationlink", "label")
        return value.isEmpty ? "Overview" : value
    }

    private var searchPrompt: String {
        let value = state.control("searchable", "prompt")
        return value.isEmpty ? "Search folders" : value
    }
}
