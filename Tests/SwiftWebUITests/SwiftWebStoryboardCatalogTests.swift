import Foundation
import SwiftHTML
import SwiftWebUIRuntime
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

    private func occurrences(of needle: String, in haystack: String) -> Int {
        haystack.components(separatedBy: needle).count - 1
    }

    /// Every `href="#anchor"` in the rendered page (the inspector table of
    /// contents); the in-page sidebar links use real paths, not fragments, so
    /// these are the table-of-contents targets.
    private func tableOfContentsAnchors(in html: String) -> [String] {
        var anchors: [String] = []
        var remainder = Substring(html)
        while let range = remainder.range(of: "href=\"#") {
            let after = remainder[range.upperBound...]
            guard let end = after.firstIndex(of: "\"") else { break }
            let anchor = String(after[..<end])
            if !anchor.isEmpty {
                anchors.append(anchor)
            }
            remainder = after[end...]
        }
        return anchors
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

        #expect(rendered.contains("SwiftWebUI"))
        #expect(rendered.contains("Storyboard"))
        #expect(rendered.contains("Search components"))
        #expect(rendered.contains("Text"))
        #expect(rendered.contains("Preview"))
        #expect(rendered.contains("Usage"))
        #expect(rendered.contains("Rendered HTML"))
        #expect(rendered.contains("Properties"))
        #expect(rendered.contains("Related"))
        #expect(rendered.contains("Text(_:as:)"))
        #expect(rendered.contains("Text(\"Hello, SwiftWebUI\")"))
    }

    @Test
    func topBarShowsBrandAndShellControls() {
        let rendered = StoryboardCatalog().render()

        #expect(rendered.contains("SwiftWebUI"))
        #expect(rendered.contains("Search components"))
        #expect(rendered.contains("Docs"))
        #expect(rendered.contains("GitHub ↗"))
        #expect(rendered.contains("href=\"https://github.com/1amageek/swift-web\""))
        #expect(rendered.contains("Light"))
        #expect(rendered.contains("Dark"))
        #expect(!rendered.contains("Style System"))
        #expect(!rendered.contains("Liquid Glass"))
    }

    @Test
    func catalogEmitsSemanticLandmarks() {
        let rendered = StoryboardCatalog(initialSelection: "list").render()

        #expect(rendered.contains("role=\"banner\""))
        #expect(rendered.contains("role=\"navigation\""))
        #expect(rendered.contains("aria-label=\"Components\""))
        #expect(rendered.contains("role=\"complementary\""))
        #expect(rendered.contains("role=\"main\""))
        #expect(rendered.contains("<h1"))
        #expect(rendered.contains("<h2"))
        #expect(rendered.contains("id=\"properties\""))
        #expect(rendered.contains("id=\"related\""))
    }

    @Test
    func catalogHasExactlyOneH1() {
        for selection in ["typography", "list", "spacing", "button"] {
            let rendered = StoryboardCatalog(initialSelection: selection).render()
            #expect(occurrences(of: "<h1", in: rendered) == 1, "expected one <h1> for \(selection)")
        }
    }

    @Test
    func tableOfContentsAnchorsResolveToSectionIDs() {
        // "list" shows the Rendered HTML section; "spacing" does not — both must
        // keep every table-of-contents anchor pointing at a real section id.
        for selection in ["list", "spacing"] {
            let rendered = StoryboardCatalog(initialSelection: selection).render()
            let anchors = tableOfContentsAnchors(in: rendered)
            #expect(!anchors.isEmpty, "expected TOC anchors for \(selection)")
            for anchor in anchors {
                #expect(
                    rendered.contains("id=\"\(anchor)\""),
                    "TOC anchor #\(anchor) has no matching section id for \(selection)"
                )
            }
        }
    }

    @Test
    func breadcrumbShowsCategoryAndComponent() {
        let rendered = StoryboardCatalog(initialSelection: "list").render()

        if let category = catalogCategory(for: "list") {
            #expect(self.rendered(rendered, contains: category.title))
        }
        #expect(rendered.contains("List"))
    }

    @Test
    func sidebarRowsRenderCanonicalCatalogPaths() {
        let rendered = StoryboardCatalog(initialSelection: "list").render()

        #expect(rendered.contains("href=\"/storyboard/list\""))
        #expect(rendered.contains("href=\"/storyboard/stacks\""))
        // Exactly one row is the current page (not just "at least one").
        #expect(occurrences(of: "aria-current=\"page\"", in: rendered) == 1)
    }

    @Test
    func invalidInitialSelectionFallsBackToDefaultSelection() {
        let rendered = StoryboardCatalog(initialSelection: "missing-component").render()

        #expect(rendered.contains("href=\"/storyboard/typography\""))
        #expect(rendered.contains("Text"))
        #expect(rendered.contains("aria-current=\"page\""))
    }

    @Test
    func propertyPanelRendersNameValueAndSummary() {
        let rendered = StoryboardCatalog(initialSelection: "section").render()
        let spec = catalogDetailSpec(for: catalogItem(for: "section")!)

        for property in spec.properties {
            #expect(self.rendered(rendered, contains: property.name))
            #expect(self.rendered(rendered, contains: property.acceptedValues))
            #expect(self.rendered(rendered, contains: property.summary))
        }
    }

    @Test
    func bootstrapInitialSelectionFollowsStoryboardPath() throws {
        let catalog = try StoryboardCatalog(
            bootstrap: ClientWasmBootstrapRequest(
                hydrationIndex: .empty,
                location: ClientWasmBootstrapLocation(
                    href: "http://127.0.0.1:3001/storyboard/stepper",
                    search: ""
                )
            )
        )
        let rendered = catalog.render()

        #expect(rendered.contains("href=\"/storyboard/stepper\""))
        #expect(rendered.contains("Stepper"))
        #expect(rendered.contains("aria-current=\"page\""))
        #expect(rendered.contains("swui-stepper"))
    }

    @Test
    func everyCatalogSelectionRendersDocumentationDetail() {
        for item in allItems {
            let rendered = StoryboardCatalog(initialSelection: item.id).render()
            let spec = catalogDetailSpec(for: item)

            #expect(self.rendered(rendered, contains: item.name), "Missing selected component title for \(item.id)")
            #expect(self.rendered(rendered, contains: spec.overview), "Missing overview copy for \(item.id)")
            #expect(rendered.contains("Properties"), "Missing property section for \(item.id)")
            #expect(rendered.contains("Usage"), "Missing usage section for \(item.id)")

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
    func spacingPreviewRendersScaleAndGridLabel() {
        let rendered = StoryboardCatalog(initialSelection: "spacing").render()

        #expect(rendered.contains("8px grid"))
        #expect(rendered.contains("base unit"))
    }

    @Test
    func catalogCoversPrimarySwiftWebUIComponents() {
        let coverageText = allItems.map { item in
            let spec = catalogDetailSpec(for: item)
            return "\(item.name)\n\(item.code)\n\(spec.snippet)"
        }.joined(separator: "\n")

        let requiredNames = [
            "GridSystem",
            "GroupBox",
            "CodeBlock",
            "Text",
            "Heading",
            "Button",
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
            "Toolbar",
            "Badge",
            "List",
            "ListRow",
            "Section",
            "DisclosureGroup",
            "Grid",
            "Divider",
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
