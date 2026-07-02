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
                    StoryboardDetailIsland(initialSelection: item.id)
                    propertiesSection(spec.properties)
                    relatedSection(item: item)
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 30)
            .padding(.vertical, 22)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .accessibilityRole("main")
    }

    private func sectionTitle(_ title: String, anchor: String) -> some HTML {
        Text(title, as: .h2, .id(anchor))
            .font(.headline)
            .fontWeight(.semibold)
    }

    @HTMLBuilder
    private func detailHeader(item: CatalogItem, spec: CatalogDetailSpec) -> some HTML {
        if let category = catalogCategory(for: item.id) {
            HStack(spacing: .xsmall) {
                Text(category.title)
                Text("/").accessibilityHidden(true)
                Text(item.name)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        Text(item.name, as: .h1)
            .font(.title)
            .fontWeight(.bold)
        Text(spec.overview)
            .foregroundStyle(.secondary)
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
    }

    @HTMLBuilder
    private func relatedSection(item: CatalogItem) -> some HTML {
        VStack(alignment: .leading, spacing: .small) {
            sectionTitle("Related", anchor: "related")
            CatalogRelatedPanel(selection: item.id)
        }
    }
}
