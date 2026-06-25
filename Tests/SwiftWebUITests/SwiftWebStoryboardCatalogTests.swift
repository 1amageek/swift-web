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

    private func codeBlock(language: String, in html: String) -> String? {
        guard let languageRange = html.range(of: "data-language=\"\(language)\""),
              let endRange = html[languageRange.upperBound...].range(of: "</pre>") else {
            return nil
        }
        return String(html[languageRange.upperBound..<endRange.lowerBound])
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
        #expect(rendered.contains("DOM Contract"))
        #expect(rendered.contains("Properties"))
        #expect(rendered.contains("Related"))
        #expect(rendered.contains("Text(_:as:)"))
        #expect(rendered.contains("Text(\"Hello, SwiftWebUI\")"))
    }

    @Test
    func domContractPanelUsesStableClassOnlyMarkup() {
        let rendered = StoryboardCatalog(initialSelection: "list").render()
        let htmlCode = codeBlock(language: "html", in: rendered) ?? ""

        #expect(htmlCode.contains("&lt;div class=\"swui-"))
        #expect(!htmlCode.contains("style=\""))
        #expect(!htmlCode.contains("-x"))
        #expect(!htmlCode.contains("data-node"))
    }

    @Test
    func domContractSanitizerKeepsPublicUtilityClassesOnly() {
        let html = #"<div class="swui-vstack swui-gap-sm swui-ai-center swui-w-237px-x12345678 swui-modifier" data-node="1" data-event-click="2"></div>"#
        let contract = storyboardDOMContractHTML(from: html)

        #expect(contract == #"<div class="swui-vstack swui-gap-sm swui-ai-center"></div>"#)
    }

    @Test
    func colorControlsExposeVisibleSwatchesAndStableRangeLayout() {
        let rendered = StoryboardCatalog(initialSelection: "colorvalue").render()

        for value in ["#007aff", "#34c759", "#ff9500", "#ff2d55", "#af52de"] {
            #expect(rendered.contains(value), "Missing swatch fill \(value)")
        }
        for token in [
            "swui-storyboard-swatch-button",
            "swui-storyboard-range-widget",
            "swui-storyboard-range-slider",
            "swui-storyboard-range-readout",
        ] {
            #expect(rendered.contains(token), "Missing control layout class \(token)")
        }
        #expect(rendered.contains("grid-template-columns: 132px 4ch"))
        #expect(rendered.contains("min-width: 0"))
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
        // Every visible table-of-contents anchor must point at a real section id.
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
    func storyboardControlDefaultsCoverEveryRegisteredControl() {
        let expectedKeys = Set(allItems.flatMap { item in
            storyboardControls(for: item.id).map { "\(item.id).\($0.id)" }
        })
        let actualKeys = Set(storyboardControlDefaults.keys)
        let missingKeys = expectedKeys.subtracting(actualKeys).sorted()

        #expect(missingKeys.isEmpty, "Missing storyboard defaults: \(missingKeys.joined(separator: ", "))")
    }

    @Test
    func generatedSnippetEscapesSwiftStringLiterals() {
        let snippet = catalogSnippet(
            for: "typography",
            state: ["typography.text": "Ada \"Lovelace\" \\ Engine\nLine"]
        )

        #expect(snippet.contains(#"Text("Ada \"Lovelace\" \\ Engine\nLine")"#))
    }

    @Test
    func badgeSnippetUsesTheSameTintContractAsThePreview() {
        let snippet = catalogSnippet(
            for: "badge",
            state: [
                "badge.label": "Ready",
                "badge.tint": "danger",
            ]
        )
        let rendered = StoryboardCatalog(initialSelection: "badge").render()

        #expect(snippet == "Badge(\"Ready\")\n    .tint(.danger)")
        #expect(rendered.contains("--swui-control-tint: var(--swui-accent)"))
    }

    @Test
    func gridStoryboardUsesStaticGridContract() {
        let snippet = catalogSnippet(for: "grid", state: [:])
        let rendered = StoryboardCatalog(initialSelection: "grid").render()

        #expect(storyboardControls(for: "grid").isEmpty)
        #expect(storyboardControlDefaults["grid.min"] == nil)
        #expect(snippet.contains("Grid(horizontalSpacing: 12, verticalSpacing: 12)"))
        #expect(snippet.contains("GridRow"))
        #expect(!snippet.contains("minColumnWidth"))
        #expect(!snippet.contains("LazyVGrid"))
        #expect(!snippet.contains(#""120px""#))
        #expect(rendered.contains("swui-grid"))
        #expect(rendered.contains("swui-grid-row"))
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
            "Code",
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
