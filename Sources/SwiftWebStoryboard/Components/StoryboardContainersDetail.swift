import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Containers

struct ContainersDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
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
        case "valuedisplay":
            HStack(spacing: .medium) {
                ValueDisplay(label: "Score", value: 42)
                ValueDisplay(label: "Streak", value: 7)
                ValueDisplay(label: "Grade", value: "A+")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
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
            Grid(minColumnWidth: "220px", spacing: .large) {
                CatalogVariant("LazyVStack") {
                    LazyVStack(alignment: .leading, spacing: .small) {
                        Badge("Row 1")
                        Badge("Row 2")
                        Badge("Row 3")
                    }
                }
                CatalogVariant("LazyHStack") {
                    LazyHStack(spacing: .small) {
                        Badge("A")
                        Badge("B")
                        Badge("C")
                    }
                }
                CatalogVariant("LazyVGrid") {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: .small) {
                        Badge("1")
                        Badge("2")
                        Badge("3")
                        Badge("4")
                    }
                }
                CatalogVariant("LazyHGrid") {
                    LazyHGrid(rows: [GridItem(.fixed(28)), GridItem(.fixed(28))], spacing: .small) {
                        Badge("1")
                        Badge("2")
                        Badge("3")
                        Badge("4")
                    }
                }
            }
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
            .frame(maxWidth: .infinity, height: "160px")
            .background("var(--swui-surface-raised)")
            .cornerRadius("12px")
            .style { .border("1px solid var(--swui-border)") }
        default:
            Card {
                VStack(alignment: .leading, spacing: .small) {
                    Heading("Card title", level: .subsection)
                    Text("Cards group related content on the shared surface material.", tone: .muted)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

