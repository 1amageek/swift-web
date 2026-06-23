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
            Badge(value("badge", "label", "Ready"))
        case "toolbar":
            Toolbar {
                Button(value("toolbar", "label", "Back")).buttonStyle(.plain)
                Spacer()
                Button("Save").buttonStyle(.borderedProminent)
            }
        case "list":
            List {
                ListRow { Text("Wi-Fi"); Spacer(); Badge("On") }
                ListRow { Text("Bluetooth"); Spacer(); Text("Off").foregroundStyle(.secondary) }
                ListRow { Text("Updates"); Spacer(); Badge("3") }
            }
            .listStyle(listStyleKind(state.control("list", "style")))
        case "section":
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
        case "disclosuregroup":
            DisclosureGroup("Advanced options", isExpanded: ui.bool("disclosuregroup.open")) {
                VStack(alignment: .leading, spacing: .small) {
                    Text("Nested content reveals when expanded.").foregroundStyle(.secondary)
                    Label("Verbose logging", systemImage: "doc.text")
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "grid":
            Grid(alignment: .center, horizontalSpacing: 8, verticalSpacing: 8) {
                GridRow { Badge("Cell 1"); Badge("Cell 2") }
                GridRow { Badge("Cell 3"); Badge("Cell 4") }
            }
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
                    ForEach(["Ada", "Grace", "Alan", "Katherine"], id: \.self) { name in
                        Badge(name)
                    }
                }
                .padding(.all, 8)
            } else {
                LazyVStack(alignment: .leading, spacing: .small) {
                    ForEach(["Ada Lovelace", "Grace Hopper", "Alan Turing", "Katherine Johnson"], id: \.self) { name in
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
                ForEach(1...8, id: \.self) { index in
                    Badge("Item 0\(index)")
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
