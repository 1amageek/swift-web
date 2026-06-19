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
                    Text("Summary panel content.", tone: .muted)
                }
                Tab("Activity", systemImage: "chart.bar", value: "activity") {
                    Text("Activity panel content.", tone: .muted)
                }
                Tab("Settings", systemImage: "gear", value: "settings") {
                    Text("Settings panel content.", tone: .muted)
                }
            }
        case "navigationlink":
            VStack(alignment: .leading, spacing: .small) {
                NavigationLink("Overview", href: "#overview")
                NavigationLink(href: "#settings") {
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
                    NavigationLink("Overview", href: "#")
                    NavigationLink("Components", href: "#components")
                    NavigationLink("Tokens", href: "#tokens")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}

