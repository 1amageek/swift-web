import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Navigation & tabs

struct NavigationDetail: Component {
    let selection: String
    let tab: Binding<String>
    let query: Binding<String>

    var body: some HTML {
        switch selection {
        case "tabview":
            TabView(selection: tab) {
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
            VStack(alignment: .leading, spacing: .small) {
                NavigationLink("Overview", destination: URL(string: "#overview")!)
                NavigationLink(destination: URL(string: "#settings")!) {
                    Label("Settings", systemImage: "gear")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "searchable":
            List {
                ListRow { Text("Inbox") }
                ListRow { Text("Drafts") }
                ListRow { Text("Sent") }
            }
            .searchable(text: query)
        default:
            NavigationStack {
                VStack(alignment: .leading, spacing: .small) {
                    NavigationLink("Overview", destination: URL(string: "#")!)
                    NavigationLink("Components", destination: URL(string: "#components")!)
                    NavigationLink("Tokens", destination: URL(string: "#tokens")!)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
