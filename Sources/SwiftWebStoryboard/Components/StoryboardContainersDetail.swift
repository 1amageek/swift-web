import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Containers

struct ContainersDetail: Component {
    let selection: String
    /// Shared control-panel state, keyed "componentID.knob".
    let ui: Binding<[String: String]>

    private var state: [String: String] { ui.wrappedValue }

    var body: some HTML {
        switch selection {
        case "badge":
            // A row of badges: the first reflects the Label + Tint controls, the
            // others are fixed references (default surface, danger) so the tint is
            // evaluable against neighbours.
            let badgeLabel = value("badge", "label", "Ready")
            let selectedBadgeTint = state.control("badge", "tint")
            HStack(spacing: .small) {
                Badge(badgeLabel)
                    .tint(badgeTintColor(selectedBadgeTint))
                Badge("Default")
                Badge("Beta")
                    .tint(.danger)
            }
        case "toolbar":
            // The Primary control drives the leading-trailing primary action; the
            // Back button is a fixed secondary reference, matching the design.
            Toolbar {
                Button("Back").buttonStyle(.bordered).controlSize(.small)
                Spacer()
                Button(value("toolbar", "label", "Save")).buttonStyle(.borderedProminent).controlSize(.small)
            }
        case "list":
            List {
                ListRow { Text("Wi-Fi"); Spacer(); Badge("On") }
                ListRow { Text("Bluetooth"); Spacer(); Text("Off").foregroundStyle(.secondary) }
                ListRow { Text("Updates"); Spacer(); Badge("3") }
            }
            .listStyle(listStyleKind(state.control("list", "style")))
        case "section":
            // The first section reflects the Header + Footer controls; a fixed
            // "Devices" section follows so grouped sections are evaluable as a
            // list, matching the design.
            VStack(alignment: .leading, spacing: .medium) {
                Section {
                    VStack(alignment: .leading, spacing: .small) {
                        Text("Profile")
                        Text("Security")
                        Text("Notifications")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Heading(value("section", "title", "Account"), level: .subsection)
                } footer: {
                    Text(footerText).foregroundStyle(.secondary)
                }
                Section {
                    VStack(alignment: .leading, spacing: .small) {
                        Text("iPhone")
                        Text("iPad")
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } header: {
                    Heading("Devices", level: .subsection)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "disclosuregroup":
            DisclosureGroup("Advanced options", isExpanded: ui.bool("disclosuregroup.open")) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Nested content reveals when expanded.").foregroundStyle(.secondary)
                    Label("Verbose logging", systemImage: "doc.text")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "grid":
            gridDemo()
        case "lazy":
            lazyDemo(state.control("lazy", "axis"))
        case "scrollview":
            scrollViewDemo()
        default: // groupbox
            GroupBox(value("groupbox", "title", "Storage")) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("iCloud Drive")
                    Text("128 GB of 200 GB used").foregroundStyle(.secondary)
                }
                .padding(padding(state.control("groupbox", "pad")))
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    @HTMLBuilder
    private func lazyDemo(_ axis: String) -> some HTML {
        ScrollView(.vertical) {
            if axis == "hstack" {
                LazyHStack(spacing: .small) {
                    ForEach(["Ada", "Grace", "Alan", "Katherine"], id: { name in name }) { name in
                        Text(name)
                    }
                }
                .padding(.all, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: .small) {
                    ForEach(["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson"], id: { name in name }) { name in
                        HStack(spacing: .small) {
                            Image(systemName: "envelope")
                            Text(name)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(.all, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: 280, height: 160)
        .background(.surfaceRaised)
        .cornerRadius(12)
        .border(.border)
    }

    @HTMLBuilder
    private func scrollViewDemo() -> some HTML {
        let height = state.controlNumber("scrollview", "height")
        ScrollView(state.control("scrollview", "axes") == "horizontal" ? .horizontal : .vertical) {
            VStack(alignment: .leading, spacing: .small) {
                ForEach(1...8, id: { index in index }) { index in
                    Text("Item 0\(index)")
                }
            }
            .padding(.all, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, height: height)
        .background(.surfaceRaised)
        .cornerRadius(12)
        .border(.border)
    }

    @HTMLBuilder
    private func gridDemo() -> some HTML {
        Grid(horizontalSpacing: 12, verticalSpacing: 12) {
            GridRow {
                gridTile(0)
                gridTile(1)
                gridTile(2)
            }
            GridRow {
                gridTile(3)
                gridTile(4)
                gridTile(5)
            }
        }
        .frame(width: 340)
    }

    private func gridTile(_ index: Int) -> some HTML {
        div(.class("swui-storyboard-grid-tile swui-storyboard-grid-tile-\(index)")) {
            Image(systemName: "photo")
        }
    }

    private func badgeTintColor(_ tint: String) -> Color {
        switch tint {
        case "danger":
            return .danger
        case "primary":
            return .primary
        case "secondary":
            return .secondary
        default: // accent
            return .accent
        }
    }

    private func value(_ id: String, _ key: String, _ fallback: String) -> String {
        let current = state.control(id, key)
        return current.isEmpty ? fallback : current
    }

    private var footerText: String {
        let value = state.control("section", "footer")
        return value.isEmpty ? "Signed in as ada@example.com" : value
    }

    private func listStyleKind(_ value: String) -> ListStyleKind {
        switch value {
        case "inset": return .inset
        case "grouped": return .grouped
        case "insetGrouped": return .insetGrouped
        case "sidebar": return .sidebar
        default: return .plain
        }
    }

    private func padding(_ value: String) -> Space {
        switch value {
        case "compact": return .small
        case "roomy": return .large
        default: return .medium
        }
    }
}
