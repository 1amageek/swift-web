import Foundation
import SwiftHTML
@testable import SwiftWebStoryboard
import Testing

@Suite
struct SwiftWebStoryboardCatalogTests {
    private var allItems: [CatalogItem] {
        catalogCategories.flatMap(\.items)
    }

    private func rendered(_ html: String, contains value: String) -> Bool {
        html.contains(value) || html.contains(escapedHTML(value))
    }

    private func escapedHTML(_ value: String) -> String {
        value
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    @Test
    func everyCatalogItemHasDocumentationMetadata() {
        for item in allItems {
            let spec = catalogDetailSpec(for: item)

            #expect(!item.name.isEmpty)
            #expect(!spec.overview.isEmpty, "Missing overview for \(item.id)")
            #expect(!spec.properties.isEmpty, "Missing adjustable properties for \(item.id)")
            #expect(!spec.snippet.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Missing snippet for \(item.id)")
        }
    }

    @Test
    func defaultCatalogRenderShowsDocumentationSections() {
        let rendered = StoryboardCatalog().render()

        #expect(rendered.contains("Typography"))
        #expect(rendered.contains("Adjustable properties"))
        #expect(rendered.contains("Swift snippet"))
        #expect(rendered.contains("Accepted values"))
        #expect(rendered.contains("Heading(\"Page heading\", level: .page)"))
    }

    @Test
    func everyCatalogSelectionRendersDocumentationDetail() {
        for item in allItems {
            let rendered = StoryboardCatalog(initialSelection: item.id).render()
            let spec = catalogDetailSpec(for: item)

            #expect(self.rendered(rendered, contains: item.name), "Missing selected component title for \(item.id)")
            #expect(self.rendered(rendered, contains: spec.overview), "Missing overview copy for \(item.id)")
            #expect(rendered.contains("Adjustable properties"), "Missing property section for \(item.id)")
            #expect(rendered.contains("Swift snippet"), "Missing snippet section for \(item.id)")

            for property in spec.properties {
                #expect(self.rendered(rendered, contains: property.name), "Missing property name \(property.name) for \(item.id)")
                #expect(self.rendered(rendered, contains: property.acceptedValues), "Missing accepted values for \(property.name) in \(item.id)")
                #expect(self.rendered(rendered, contains: property.summary), "Missing property behavior for \(property.name) in \(item.id)")
            }

            let snippetProbe = spec.snippet
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .first { !$0.isEmpty }

            if let snippetProbe {
                #expect(self.rendered(rendered, contains: String(snippetProbe)), "Missing snippet body for \(item.id)")
            }
        }
    }

    @Test
    func catalogCoversPrimarySwiftWebUIComponents() {
        let coverageText = allItems.map { item in
            let spec = catalogDetailSpec(for: item)
            return "\(item.name)\n\(item.code)\n\(spec.snippet)"
        }.joined(separator: "\n")

        let requiredNames = [
            "Text",
            "TextBlock",
            "Heading",
            "Button",
            "ButtonLink",
            "SubmitButton",
            "TextField",
            "SecureField",
            "TextEditor",
            "Toggle",
            "Slider",
            "Stepper",
            "DatePicker",
            "ColorPicker",
            "Form",
            "Picker",
            "PickerOption",
            "Menu",
            "Card",
            "Toolbar",
            "Badge",
            "ValueDisplay",
            "List",
            "ListRow",
            "Section",
            "DisclosureGroup",
            "Grid",
            "LazyVStack",
            "LazyHStack",
            "LazyVGrid",
            "LazyHGrid",
            "ScrollView",
            "ProgressView",
            "Gauge",
            "NavigationStack",
            "NavigationLink",
            "TabView",
            "Tab",
            "VStack",
            "HStack",
            "ZStack",
            "Spacer",
            "Divider",
            "Image",
            "Label",
        ]

        for name in requiredNames {
            #expect(coverageText.contains(name), "Storyboard does not cover \(name)")
        }
    }
}
