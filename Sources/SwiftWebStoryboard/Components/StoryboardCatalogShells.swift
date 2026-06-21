import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Shells

/// A compact prop-reference table for the selected component.
struct CatalogPropertyPanel: Component {
    let properties: [CatalogProperty]

    var body: some HTML {
        VStack(alignment: .leading, spacing: Space.none) {
            ForEach(properties) { property in
                CatalogPropertyRow(property: property)
            }
        }
        .class("storyboard-property-panel")
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct CatalogPropertyRow: Component {
    let property: CatalogProperty

    var body: some HTML {
        VStack(alignment: .leading, spacing: .xsmall) {
            HStack(spacing: .small) {
                code(.class("storyboard-property-name")) {
                    property.name
                }
                code(.class("storyboard-property-values")) {
                    property.acceptedValues
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text(property.summary).foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .class("storyboard-property-row")
    }
}

struct CatalogRelatedPanel: Component {
    let selection: String

    var body: some HTML {
        HStack(spacing: .medium) {
            ForEach(relatedItems) { item in
                a(.href(item.path), .class("storyboard-related-link")) {
                    Text(item.name, as: .strong)
                    Text(item.summary).foregroundStyle(.secondary)
                }
            }
        }
        .class("storyboard-related-grid")
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var relatedItems: [CatalogItem] {
        guard let category = catalogCategory(for: selection) else {
            return []
        }
        return Array(category.items.filter { $0.id != selection }.prefix(3))
    }
}
