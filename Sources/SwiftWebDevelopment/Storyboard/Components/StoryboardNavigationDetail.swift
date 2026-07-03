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
            TabView(selection: ui.string("tabview.tab")) {
                Tab("Summary", systemImage: "doc.text", value: "summary") {
                    Text("Summary panel content.").foregroundStyle(.secondary)
                }
                Tab("Activity", systemImage: "chart.bar", value: "activity") {
                    Text("Activity panel content.").foregroundStyle(.secondary)
                }
                Tab("Settings", systemImage: "gear", value: "settings") {
                    Text("Settings panel content.").foregroundStyle(.secondary)
                }
            }
        case "navigationlink":
            NavigationLink(linkLabel, destination: URL(string: "#overview")!)
        case "searchable":
            List {
                Text("Inbox")
                Text("Drafts")
                Text("Sent")
            }
            .searchable(text: ui.string("searchable.query"), prompt: "Search folders")
        default:
            NavigationStack {
                VStack(alignment: .leading, spacing: .small) {
                    NavigationLink("Overview", destination: URL(string: "#overview")!)
                    NavigationLink("Components", destination: URL(string: "#components")!)
                    NavigationLink("Tokens", destination: URL(string: "#tokens")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle(state.control("navigationstack", "title"))
        }
    }

    private var linkLabel: String {
        let value = state.control("navigationlink", "label")
        return value.isEmpty ? "Overview" : value
    }
}
