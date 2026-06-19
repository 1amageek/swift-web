import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Shells

/// Inline monospace chip naming the call site of the entry's component.
struct CatalogCodeChip: Component {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some HTML {
        Text(text, as: .code)
            .padding(.all, "2px 8px")
            .background("var(--swui-surface-raised)")
            .cornerRadius("6px")
            .style {
                .border("1px solid var(--swui-border)")
                .fontFamily("var(--swui-mono-font-family)")
                .fontSize("0.82em")
            }
    }
}

/// A larger monospace block for the code that reproduces the selected preview.
struct CatalogCodeBlock: Component {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some HTML {
        CodeBlock(text, language: "swift")
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Section chrome for the center detail pane. It mirrors documentation systems
/// that separate usage, variants, and API reference without turning the preview
/// into a nested card.
struct CatalogDetailSection<Content: HTML>: Component {
    let title: String
    let caption: String
    let content: Content

    init(_ title: String, caption: String, @HTMLBuilder content: () -> Content) {
        self.title = title
        self.caption = caption
        self.content = content()
    }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .small) {
            VStack(alignment: .leading, spacing: .xsmall) {
                Heading(title, level: .subsection)
                Text(caption, tone: .muted)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A compact prop-reference table for the selected component.
struct CatalogPropertyPanel: Component {
    let properties: [CatalogProperty]

    var body: some HTML {
        VStack(alignment: .leading, spacing: Space.none) {
            HStack(spacing: .medium) {
                Text("Property", as: .small, tone: .muted)
                    .frame(width: "148px", alignment: .leading)
                Text("Accepted values", as: .small, tone: .muted)
                    .frame(width: "220px", alignment: .leading)
                Text("Behavior", as: .small, tone: .muted)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.all, "10px 14px")
            .style {
                .custom("border-bottom", "1px solid var(--swui-border)")
                .fontWeight("650")
            }

            ForEach(properties) { property in
                CatalogPropertyRow(property: property)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background("var(--swui-surface)")
        .cornerRadius("12px")
        .style {
            .border("1px solid var(--swui-border)")
            .custom("overflow", "hidden")
        }
    }
}

struct CatalogPropertyRow: Component {
    let property: CatalogProperty

    var body: some HTML {
        HStack(alignment: .top, spacing: .medium) {
            Text(property.name, as: .strong)
                .frame(width: "148px", alignment: .leading)
            CatalogCodeChip(property.acceptedValues)
                .frame(width: "220px", alignment: .leading)
            Text(property.summary, tone: .muted)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.all, "12px 14px")
        .style {
            .custom("border-bottom", "1px solid color-mix(in srgb, var(--swui-border) 70%, transparent)")
        }
    }
}

/// A captioned slot inside a demo, used to label a single variant.
struct CatalogVariant<Content: HTML>: Component {
    let label: String
    let content: Content

    init(_ label: String, @HTMLBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            Text(label, as: .small, tone: .muted)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// A vivid backdrop so a material/glass surface's backdrop blur and refraction
/// read. The gradient is the stage's own background; children blur it through
/// `backdrop-filter` when the style system is Liquid Glass.
struct CatalogGlassStage<Content: HTML>: Component {
    let content: Content
    init(@HTMLBuilder content: () -> Content) { self.content = content() }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .medium) {
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.all, "20px")
        .cornerRadius("16px")
        .style {
            .background("radial-gradient(440px 220px at 12% 16%, #ff7a7a, transparent 62%), radial-gradient(460px 240px at 88% 18%, #5b8cff, transparent 62%), radial-gradient(560px 280px at 50% 120%, #2dd4a7, transparent 60%), #0f172a")
            .border("1px solid var(--swui-border)")
        }
    }
}

/// A labeled panel filled with a material level via `.background(_:in:)`.
struct CatalogMaterialSwatch: Component {
    let title: String
    let code: String
    let material: Material

    init(_ title: String, code: String, material: Material) {
        self.title = title
        self.code = code
        self.material = material
    }

    var body: some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            Text(title, as: .strong)
            Text(code, as: .small, tone: .muted)
        }
        .padding(.all, "16px")
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(material, in: .rect(cornerRadius: 16))
    }
}
