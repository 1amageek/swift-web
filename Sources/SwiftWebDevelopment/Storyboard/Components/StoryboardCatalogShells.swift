import Foundation
import SwiftHTML
import SwiftWebUI

// MARK: - Shells

/// The prop-reference table for the selected component: one aligned grid, the
/// parameter in a monospaced column, its accepted values and summary beside it.
struct CatalogPropertyPanel: Component {
    let properties: [CatalogProperty]

    var body: some HTML {
        div(.class("swui-storyboard-props")) {
            ForEach(properties) { property in
                div(.class("swui-storyboard-props-row")) {
                    Text(property.name).as(.span)
                        .font(Font(size: .px(13), weight: .semibold, design: .monospaced))
                    VStack(alignment: .leading, spacing: .xsmall) {
                        Text(property.acceptedValues).as(.span)
                            .font(Font(size: .px(12.5), design: .monospaced))
                            .foregroundStyle(.accent)
                        Text(property.summary).as(.span)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
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
                .clipShape(.rect(cornerRadius: 10))
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
