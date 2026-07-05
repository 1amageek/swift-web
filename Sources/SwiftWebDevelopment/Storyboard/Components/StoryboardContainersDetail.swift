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
            // A settings-style list showing the standard badge(_:) usage: the
            // first row reflects the Label + Kind + Tint controls, the following
            // rows are fixed references (default surface, danger) so the tint is
            // evaluable against neighbours.
            List {
                badgeFirstRow(
                    kind: state.control("badge", "kind"),
                    label: value("badge", "label", "Ready"),
                    tint: badgeTintColor(state.control("badge", "tint"))
                )
                Text("Notifications").badge("Default")
                Text("Updates")
                    .badge("Beta")
                    .tint(.danger)
            }
        case "toolbar":
            toolbarDemo()
        case "list":
            List {
                Text("Wi-Fi").badge("On")
                Text("Bluetooth").badge("Off")
                Text("Updates").badge(3)
            }
            .listStyle(listStyleKind(state.control("list", "style")))
        case "section":
            // The first section reflects the Header + Footer controls; a fixed
            // "Devices" section follows so grouped sections are evaluable as a
            // list, matching the design.
            div(.class("swui-storyboard-section-demo")) {
                VStack(alignment: .leading, spacing: .medium) {
                    Section {
                        VStack(alignment: .leading, spacing: .small) {
                            Text("Profile")
                            Text("Security")
                            Text("Notifications")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    } header: {
                        Text(value("section", "title", "Account")).as(.h3)
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
                        Text("Devices").as(.h3)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        case "disclosuregroup":
            disclosureGroupDemo()
        case "grid":
            gridDemo()
        case "lazy":
            lazyDemo()
        case "scrollview":
            scrollViewDemo()
        default: // groupbox
            groupBoxDemo()
        }
    }

    @HTMLBuilder
    private func badgeFirstRow(kind: String, label: String, tint: Color) -> some HTML {
        if kind == "count" {
            Text("Wi-Fi").badge(Int(label) ?? 3).tint(tint)
        } else {
            Text("Wi-Fi").badge(label).tint(tint)
        }
    }

    @HTMLBuilder
    private func toolbarDemo() -> some HTML {
        let label = value("toolbar", "label", "Save")
        let placement = toolbarPlacement(state.control("toolbar", "placement"))
        let grouped = state.controlFlag("toolbar", "group")
        // The Primary control's item routes into the selected region; the Back
        // button is a fixed navigation reference. The bar attaches above the
        // content through the toolbar modifier.
        Text("Content area")
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .navigation) {
                    Button("Back").buttonStyle(.bordered).controlSize(.small)
                }
                if grouped {
                    ToolbarItemGroup(placement: placement) {
                        Button("Edit").buttonStyle(.bordered).controlSize(.small)
                        Button(label).buttonStyle(.borderedProminent).controlSize(.small)
                    }
                } else {
                    ToolbarItem(placement: placement) {
                        Button(label).buttonStyle(.borderedProminent).controlSize(.small)
                    }
                }
            }
    }

    @HTMLBuilder
    private func disclosureGroupDemo() -> some HTML {
        let title = value("disclosuregroup", "title", "Advanced options")
        if state.controlFlag("disclosuregroup", "icon") {
            DisclosureGroup(isExpanded: ui.bool("disclosuregroup.open")) {
                disclosureContent
            } label: {
                Label(title, systemImage: "bell.badge")
            }
        } else {
            DisclosureGroup(title, isExpanded: ui.bool("disclosuregroup.open")) {
                disclosureContent
            }
        }
    }

    private var disclosureContent: some HTML {
        VStack(alignment: .leading, spacing: .small) {
            Text("Nested content reveals when expanded.").foregroundStyle(.secondary)
            Label("Verbose logging", systemImage: "doc.text")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func groupBoxDemo() -> some HTML {
        let title = value("groupbox", "title", "Storage")
        let pad = padding(state.control("groupbox", "pad"))
        if state.controlFlag("groupbox", "icon") {
            GroupBox {
                groupBoxContent(pad)
            } label: {
                Label(title, systemImage: "doc.text")
            }
        } else {
            GroupBox(title) {
                groupBoxContent(pad)
            }
        }
    }

    private func groupBoxContent(_ pad: Space) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            Text("iCloud Drive")
            Text("128 GB of 200 GB used").foregroundStyle(.secondary)
        }
        .padding(pad)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func toolbarPlacement(_ value: String) -> ToolbarItemPlacement {
        switch value {
        case "navigation": return .navigation
        case "principal": return .principal
        case "bottomBar": return .bottomBar
        default: return .primaryAction
        }
    }

    @HTMLBuilder
    private func lazyDemo() -> some HTML {
        if state.control("lazy", "kind") == "grid" {
            lazyGridDemo(adaptive: state.control("lazy", "tracks") == "adaptive")
        } else {
            lazyStackDemo(state.control("lazy", "axis"))
        }
    }

    @HTMLBuilder
    private func lazyGridDemo(adaptive: Bool) -> some HTML {
        let columns: [GridItem] = adaptive
            ? [GridItem(.adaptive(minimum: 48))]
            : [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]
        ScrollView(.vertical) {
            LazyVGrid(columns: columns, spacing: .small) {
                ForEach(1...9, id: { index in index }) { index in
                    Text(String(format: "%02d", index))
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                        .padding(.all, 6)
                        .background(Color.accent.opacity(0.12), in: .rect(cornerRadius: 6))
                }
            }
            .padding(.all, 8)
        }
        .frame(width: 280, height: 160)
        .background(.surfaceRaised)
        .border(.border)
        .clipShape(.rect(cornerRadius: 12))
    }

    @HTMLBuilder
    private func lazyStackDemo(_ axis: String) -> some HTML {
        if axis == "hstack" {
            ScrollView(.horizontal) {
                LazyHStack(spacing: .small) {
                    ForEach(["Ada", "Grace", "Alan", "Katherine"], id: { name in name }) { name in
                        Text(name)
                    }
                }
                .padding(.all, 8)
            }
            .frame(width: 280, height: 160)
            .background(.surfaceRaised)
            .border(.border)
            .clipShape(.rect(cornerRadius: 12))
        } else {
            ScrollView(.vertical) {
                LazyVStack(alignment: .leading, spacing: .small) {
                    ForEach(["Ada", "Grace", "Alan", "Katherine"], id: { name in name }) { name in
                        Text(name)
                    }
                }
                .padding(.all, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(width: 280, height: 160)
            .background(.surfaceRaised)
            .border(.border)
            .clipShape(.rect(cornerRadius: 12))
        }
    }

    @HTMLBuilder
    private func scrollViewDemo() -> some HTML {
        let height = state.controlNumber("scrollview", "height")
        let isHorizontal = state.control("scrollview", "axes") == "horizontal"
        let showsIndicators = state.controlFlag("scrollview", "showsIndicators")
        ScrollView(isHorizontal ? .horizontal : .vertical, showsIndicators: showsIndicators) {
            if isHorizontal {
                HStack(spacing: .small) {
                    ForEach(1...8, id: { index in index }) { index in
                        Text("Item 0\(index)")
                            .frame(width: 96)
                    }
                }
                .padding(.all, 8)
            } else {
                VStack(alignment: .leading, spacing: .small) {
                    ForEach(1...8, id: { index in index }) { index in
                        Text("Item 0\(index)")
                    }
                }
                .padding(.all, 8)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, height: height)
        .background(.surfaceRaised)
        .border(.border)
        .clipShape(.rect(cornerRadius: 12))
    }

    @HTMLBuilder
    private func gridDemo() -> some HTML {
        let h = state.controlNumber("grid", "hSpacing")
        let v = state.controlNumber("grid", "vSpacing")
        Grid(alignment: gridAlignment(state.control("grid", "align")), horizontalSpacing: h, verticalSpacing: v) {
            GridRow {
                Text("Name").foregroundStyle(.secondary)
                Text("Ada Lovelace")
            }
            GridRow {
                Text("Role").foregroundStyle(.secondary)
                Text("Analyst")
            }
            GridRow {
                Text("Team").foregroundStyle(.secondary)
                Text("Engines")
            }
        }
        .frame(width: 340)
    }

    private func gridAlignment(_ value: String) -> Alignment {
        switch value {
        case "leading": return .leading
        case "trailing": return .trailing
        default: return .center
        }
    }

    private func badgeTintColor(_ tint: String) -> Color {
        storyboardTintColor(tint)
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
