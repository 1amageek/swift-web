import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Shells

/// A compact prop-reference panel for the selected component.
struct CatalogPropertyPanel: Component {
    let properties: [CatalogProperty]

    var body: some HTML {
        VStack(alignment: .leading, spacing: .medium) {
            ForEach(properties) { property in
                CatalogPropertyRow(property: property)
            }
        }
        .padding(.large)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.surfaceRaised, in: .rect(cornerRadius: 12))
        .border(.border, width: 1)
        .cornerRadius(12)
    }
}

struct CatalogPropertyRow: Component {
    let property: CatalogProperty

    var body: some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            HStack(spacing: .small) {
                Text(property.name)
                    .font(Font(size: .px(13), weight: .semibold, design: .monospaced))
                Text(property.acceptedValues)
                    .font(Font(size: .px(13), design: .monospaced))
                    .foregroundStyle(.accent)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(property.summary)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CatalogRelatedPanel: Component {
    let selection: String

    var body: some HTML {
        HStack(alignment: .top, spacing: .medium) {
            ForEach(relatedItems) { item in
                Link(destination: URL(string: item.path)!) {
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text(item.name)
                            .fontWeight(.semibold)
                        Text(item.summary)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .foregroundStyle(.primary)
                .padding(.medium)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.surfaceRaised, in: .rect(cornerRadius: 10))
                .border(.border, width: 1)
                .cornerRadius(10)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var relatedItems: [CatalogItem] {
        guard let category = catalogCategory(for: selection) else {
            return []
        }
        return Array(category.items.filter { $0.id != selection }.prefix(3))
    }
}
