import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail router

/// The center pane. A registry-driven header names the component; the demo is
/// routed by category to keep each switch small, then by component id.
struct CatalogDetail: Component {
    let selection: String
    let name: Binding<String>
    let email: Binding<String>
    let secret: Binding<String>
    let notes: Binding<String>
    let enabled: Binding<Bool>
    let volume: Binding<Double>
    let density: Binding<Int>
    let due: Binding<Date>
    let accent: Binding<String>
    let pick: Binding<String>
    let segment: Binding<String>
    let scope: Binding<String>
    let menuPick: Binding<String>
    let tab: Binding<String>
    let query: Binding<String>
    let showsAlert: Binding<Bool>
    let showsConfirmation: Binding<Bool>
    let showsSheet: Binding<Bool>
    let showsPopover: Binding<Bool>

    var body: some HTML {
        VStack(alignment: .leading, spacing: .large) {
            if let item = catalogItem(for: selection) {
                let spec = catalogDetailSpec(for: item)
                detailHeader(item: item, spec: spec)

                CatalogDetailSection(
                    "Live preview",
                    caption: "Interactive rendering of the selected component under the current theme and style system."
                ) {
                    Card {
                        VStack(alignment: .leading, spacing: .medium) {
                            detailDemo()
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                CatalogDetailSection(
                    "Adjustable properties",
                    caption: "Primary inputs, modifiers, and bindings that change this component's behavior."
                ) {
                    CatalogPropertyPanel(properties: spec.properties)
                }

                CatalogDetailSection(
                    "Swift snippet",
                    caption: "A minimal SwiftWebUI example that produces the preview pattern."
                ) {
                    CatalogCodeBlock(spec.snippet)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "28px 32px")
        .style {
            .height("100%")
            .custom("min-width", "0")
            .custom("overflow-y", "auto")
        }
    }

    @HTMLBuilder
    private func detailHeader(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            Heading(item.name, level: .page)
            Text(spec.overview, tone: .muted)
                .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: .small) {
                CatalogCodeChip(item.code)
                if let category = catalogCategory(for: item.id) {
                    Badge(category.title)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func detailDemo() -> some HTML {
        switch catalogCategory(for: selection)?.id ?? "foundations" {
        case "buttons":
            ButtonsDetail(selection: selection)
        case "inputs":
            InputsDetail(
                selection: selection,
                name: name,
                email: email,
                secret: secret,
                notes: notes,
                enabled: enabled,
                volume: volume,
                density: density,
                due: due,
                accent: accent
            )
        case "pickers":
            PickersDetail(selection: selection, pick: pick, segment: segment, scope: scope, menuPick: menuPick)
        case "containers":
            ContainersDetail(selection: selection)
        case "status":
            StatusDetail(selection: selection)
        case "navigation":
            NavigationDetail(selection: selection, tab: tab, query: query)
        case "presentation":
            PresentationDetail(
                selection: selection,
                showsAlert: showsAlert,
                showsConfirmation: showsConfirmation,
                showsSheet: showsSheet,
                showsPopover: showsPopover
            )
        case "layout":
            LayoutDetail(selection: selection)
        case "media":
            MediaDetail(selection: selection)
        default:
            FoundationsDetail(selection: selection)
        }
    }
}

