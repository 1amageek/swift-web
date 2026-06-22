import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Containers

struct ContainersDetail: Component {
    let selection: String
    let advancedOptionsExpanded: Binding<Bool>

    var body: some HTML {
        switch selection {
        case "groupbox":
            GroupBox {
                VStack(alignment: .leading, spacing: .small) {
                    Heading("Storage", level: .subsection)
                    Text("iCloud Drive")
                    Text("128 GB of 200 GB used").foregroundStyle(.secondary)
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
                Button("Save").buttonStyle(.borderedProminent)
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
                    Text("Off").foregroundStyle(.secondary)
                }
                ListRow {
                    Text("Updates")
                    Spacer()
                    Badge("3")
                }
            }
        case "section":
            Section {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Profile")
                    Text("Security")
                    Text("Notifications")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } header: {
                Heading("Account", level: .subsection)
            } footer: {
                Text("Signed in as ada@example.com").foregroundStyle(.secondary)
            }
        case "disclosuregroup":
            DisclosureGroup("Advanced options", isExpanded: advancedOptionsExpanded) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Nested content reveals when expanded.").foregroundStyle(.secondary)
                    Label("Verbose logging", systemImage: "doc.text")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            DisclosureGroup("Collapsed by default") {
                Text("Hidden until toggled.").foregroundStyle(.secondary)
            }
        case "grid":
            Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow {
                    Badge("Cell 1")
                    Badge("Cell 2")
                }
                GridRow {
                    Badge("Cell 3")
                    Badge("Cell 4")
                }
            }
        case "lazy":
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: .small) {
                    ForEach(["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson"], id: \.self) { name in
                        HStack(spacing: .small) {
                            Image(systemName: "envelope")
                            VStack(alignment: .leading, spacing: .xsmall) {
                                Text(name)
                                Text("Message preview").foregroundStyle(.secondary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.all, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 280, height: 160)
            .background(.surfaceRaised)
            .cornerRadius(12)
            .border(.border)
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
                .padding(.all, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, height: 160)
            .background(.surfaceRaised)
            .cornerRadius(12)
            .border(.border)
        default:
            GroupBox {
                VStack(alignment: .leading, spacing: .small) {
                    Heading("Storage", level: .subsection)
                    Text("iCloud Drive")
                    Text("128 GB of 200 GB used").foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }
}
