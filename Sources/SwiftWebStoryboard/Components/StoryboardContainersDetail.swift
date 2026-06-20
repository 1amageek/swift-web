import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Containers

struct ContainersDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "groupbox":
            div(.class("swui-group-box storyboard-groupbox-demo")) {
                VStack(alignment: .leading, spacing: .small) {
                    Heading("Storage", level: .subsection)
                    Text("iCloud Drive")
                    Text("128 GB of 200 GB used", tone: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "badge":
            HStack(spacing: .small) {
                Badge("Default")
                Badge("Ready")
                Badge("Beta")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "toolbar":
            Toolbar {
                Button("Back")
                    .buttonStyle(.plain)
                Spacer()
                Button("Preview")
                Button("Save", prominence: .primary)
            }
        case "list":
            List {
                ListRow {
                    Text("Wi-Fi")
                    Spacer()
                    Badge("On")
                }
                ListRow {
                    Text("Bluetooth")
                    Spacer()
                    Text("Off", tone: .muted)
                }
                ListRow {
                    Text("Updates")
                    Spacer()
                    Badge("3")
                }
            }
        case "section":
            Section("Account", footer: "Signed in as ada@example.com") {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Profile")
                    Text("Security")
                    Text("Notifications")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "disclosuregroup":
            DisclosureGroup("Advanced options", isExpanded: true) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Nested content reveals when expanded.", tone: .muted)
                    Label("Verbose logging", systemImage: "doc.text")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup("Collapsed by default") {
                Text("Hidden until toggled.", tone: .muted)
            }
        case "grid":
            Grid(minColumnWidth: "120px", spacing: .small) {
                Badge("Cell 1")
                Badge("Cell 2")
                Badge("Cell 3")
                Badge("Cell 4")
            }
        case "lazy":
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: .small) {
                    ForEach(["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson"], id: \.self) { name in
                        HStack(spacing: .small) {
                            Image(systemName: "envelope")
                            VStack(alignment: .leading, spacing: .xsmall) {
                                Text(name)
                                Text("Message preview", tone: .muted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.all, "8px")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 280, height: 160)
            .background("var(--swui-surface-raised)")
            .cornerRadius("12px")
            .style { .border("1px solid var(--swui-border)") }
        case "scrollview":
            ScrollView(.vertical) {
                VStack(alignment: .leading, spacing: .small) {
                    Badge("Item 01")
                    Badge("Item 02")
                    Badge("Item 03")
                    Badge("Item 04")
                    Badge("Item 05")
                    Badge("Item 06")
                    Badge("Item 07")
                    Badge("Item 08")
                }
                .padding(.all, "8px")
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, height: 160)
            .background("var(--swui-surface-raised)")
            .cornerRadius("12px")
            .style { .border("1px solid var(--swui-border)") }
        default:
            div(.class("swui-group-box storyboard-groupbox-demo")) {
                VStack(alignment: .leading, spacing: .small) {
                    Heading("Storage", level: .subsection)
                    Text("iCloud Drive")
                    Text("128 GB of 200 GB used", tone: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
