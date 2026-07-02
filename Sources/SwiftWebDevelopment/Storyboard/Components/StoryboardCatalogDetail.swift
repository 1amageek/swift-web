import Foundation
import SwiftHTML
import SwiftWebUI

struct CatalogDetail: Component {
    let selection: String

    var body: some HTML {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: .large) {
                if let item = catalogItem(for: selection) {
                    let spec = catalogDetailSpec(for: item)
                    detailHeader(item: item, spec: spec)
                    if !spec.variants.isEmpty {
                        variantsSection(item: item, spec: spec)
                    }
                    playgroundSection(item: item)
                    propertiesSection(spec.properties)
                    relatedSection(item: item)
                }
            }
            .frame(maxWidth: 860, alignment: .leading)
            .padding(.horizontal, 34)
            .padding(.vertical, 26)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .class("swui-storyboard-detail")
        .accessibilityRole("main")
    }

    private func sectionTitle(_ title: String, anchor: String) -> some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            div(.class("swui-storyboard-section-rule")) { EmptyHTML() }
            Text(title, as: .h2, .id(anchor))
                .font(.headline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func detailHeader(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        if let category = catalogCategory(for: item.id) {
            Text(category.title, as: .span, .class("swui-storyboard-eyebrow"))
        }
        HStack(alignment: .center, spacing: .medium) {
            Text(item.name, as: .h1)
                .font(.largeTitle)
                .fontWeight(.bold)
            Text(item.code, as: .code, .class("swui-storyboard-code-chip"))
        }
        if spec.discussion.isEmpty {
            Text(spec.overview, .class("swui-storyboard-lede"))
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: .small) {
                ForEach(spec.discussion, id: { $0 }) { paragraph in
                    Text(paragraph, .class("swui-storyboard-lede"))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        if let parity = spec.swiftUIParity {
            HStack(alignment: .center, spacing: .small) {
                Text("SwiftUI", as: .span, .class("swui-storyboard-code-chip"))
                Text(parity, as: .span)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @HTMLBuilder
    private func variantsSection(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Variants", anchor: "variants")
            Text("The component's range at a glance; open the playground below to drive it live.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            CatalogVariantsPanel(
                scene: StoryboardScene.scene(forItem: item.id),
                variants: spec.variants
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func playgroundSection(item: CatalogItem) -> some HTML {
        StoryboardDetailIsland(initialSelection: item.id)
    }

    @HTMLBuilder
    private func propertiesSection(_ properties: [CatalogProperty]) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Properties", anchor: "properties")
            Text("The parameters and modifiers that configure this component.")
                .font(.footnote)
                .foregroundStyle(.secondary)
            CatalogPropertyPanel(properties: properties)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @HTMLBuilder
    private func relatedSection(item: CatalogItem) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Related", anchor: "related")
            CatalogRelatedPanel(selection: item.id)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
