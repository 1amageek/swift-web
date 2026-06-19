import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Detail: Foundations

struct FoundationsDetail: Component {
    let selection: String

    var body: some HTML {
        switch selection {
        case "color":
            HStack(spacing: .small) {
                Button("Accent", prominence: .primary)
                    .tint(.accent)
                Button("Danger", prominence: .primary)
                    .tint(.danger)
                Button("Custom", prominence: .primary)
                    .tint(.css("#22a06b"))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "textblock":
            VStack(alignment: .leading, spacing: .small) {
                TextBlock("Paragraph copy for long-form content. TextBlock keeps body text semantic while using SwiftWebUI tone tokens.")
                TextBlock("Muted paragraph copy is useful for support text, captions, and explanatory content.", tone: .muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        case "materials":
            CatalogGlassStage {
                Grid(minColumnWidth: "150px", spacing: .medium) {
                    CatalogMaterialSwatch("Ultra thin", code: ".ultraThinMaterial", material: .ultraThinMaterial)
                    CatalogMaterialSwatch("Thin", code: ".thinMaterial", material: .thinMaterial)
                    CatalogMaterialSwatch("Regular", code: ".regularMaterial", material: .regularMaterial)
                    CatalogMaterialSwatch("Thick", code: ".thickMaterial", material: .thickMaterial)
                    CatalogMaterialSwatch("Ultra thick", code: ".ultraThickMaterial", material: .ultraThickMaterial)
                    CatalogMaterialSwatch("Bar", code: ".bar", material: .bar)
                }
            }
        case "glass":
            CatalogGlassStage {
                GlassEffectContainer(spacing: .medium) {
                    Text("Regular glass")
                        .padding(.all, "12px 18px")
                        .glassEffect(.regular, in: .capsule)
                    Text("Tinted + interactive")
                        .padding(.all, "12px 18px")
                        .glassEffect(.regular.tint("var(--swui-accent)").interactive(), in: .capsule)
                }

                HStack(spacing: .small) {
                    Button("Glass", prominence: .primary)
                        .buttonStyle(.glass)
                    Button("Glass prominent", prominence: .primary)
                        .buttonStyle(.glassProminent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        default:
            Heading("Page heading", level: .page)
            Heading("Section heading", level: .section)
            Heading("Subsection heading", level: .subsection)
            Text("Body copy uses the base text token and a comfortable line height for long-form reading.")
            Text("Muted secondary copy for captions and hints.", tone: .muted)
            HStack(spacing: .medium) {
                Text("Strong", as: .strong)
                Text("Small print", as: .small, tone: .muted)
                CatalogCodeChip("inline.code()")
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

