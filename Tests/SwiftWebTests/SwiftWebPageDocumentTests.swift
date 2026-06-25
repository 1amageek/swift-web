import SwiftHTML
import SwiftWebStyle
import SwiftWebUI
import Testing
import SwiftWeb
@testable import SwiftWebCore

@Suite
struct SwiftWebPageDocumentTests {
    @Test
    func resolvesAsyncPageMetadata() async throws {
        let metadata = try await AsyncMetadataPage().metadata()

        #expect(metadata.title == "Database Title")
        #expect(metadata.description == "Loaded asynchronously")
        #expect(metadata.language == "ja")
    }

    @Test
    func rendersDocumentShellFromPageMetadata() {
        let rendered = PageDocument(
            metadata: PageMetadata(
                title: "Counter",
                description: "Client and server counters.",
                language: "en"
            )
        ) {
            main {
                h1 { "Counter" }
            }
        }
        .render()

        #expect(rendered.contains("<!doctype html><html lang=\"en\">"))
        #expect(rendered.contains("<title>Counter</title>"))
        #expect(rendered.contains("<meta name=\"description\" content=\"Client and server counters.\">"))
        #expect(rendered.contains("<!--swui-atomic-->"))
        #expect(rendered.contains("<body><main><h1>Counter</h1></main></body>"))
    }

    @Test
    func pageResponseEmitsAtomicCSSInHeadWithoutInlineStyle() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            let response = try await Spacer(minLength: 12).encodePageResponse(
                for: request,
                metadata: PageMetadata(title: "Atomic")
            )
            let rendered = try #require(response.body.string)

            #expect(rendered.contains("<style id=\"swui-atomic\">.swui-minw-12px-"))
            #expect(rendered.contains("<div class=\"swui-spacer swui-minw-12px-"))
            #expect(!rendered.contains("style=\""))
            #expect(!rendered.contains("<!--swui-atomic-->"))
        }
    }

    @Test
    func pageResponseAtomizesTypedSwiftHTMLStyleAttributes() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            let response = try await div(.class("raw-element"), .style(.minWidth("14px"))) {
                "Raw"
            }
            .encodePageResponse(
                for: request,
                metadata: PageMetadata(title: "Raw Atomic")
            )
            let rendered = try #require(response.body.string)

            #expect(rendered.contains("<style id=\"swui-atomic\">.swui-minw-14px-"))
            #expect(rendered.contains("<div class=\"raw-element swui-minw-14px-"))
            #expect(!rendered.contains("style=\""))
        }
    }

    @Test
    func headAssetsEmitBaseBeforeAtomicCSS() {
        let registry = StyleRegistry()
        registry.registerStylesheet(".swui-base-layer { color: var(--swui-text); }")
        _ = registry.register(.minWidth("12px"))

        let rendered = SwiftWebHeadAssets.assets(from: registry, nonce: nil)

        #expect(containsInOrder(
            rendered,
            [
                "<style id=\"swui-base\">",
                ".swui-base-layer",
                "<style id=\"swui-atomic\">",
                ".swui-minw-12px-",
            ]
        ))
    }

    private func withApplication(
        _ body: (Application) async throws -> Void
    ) async throws {
        let application = try await Application()
        do {
            try await body(application)
            try await application.shutdown()
        } catch {
            try await application.shutdown()
            throw error
        }
    }

    private func containsInOrder(_ haystack: String, _ needles: [String]) -> Bool {
        var searchStart = haystack.startIndex
        for needle in needles {
            guard let range = haystack[searchStart...].range(of: needle) else {
                return false
            }
            searchStart = range.upperBound
        }
        return true
    }
}

private struct AsyncMetadataPage: Page {
    var title: String {
        get async throws {
            "Database Title"
        }
    }

    var description: String? {
        get async throws {
            "Loaded asynchronously"
        }
    }

    var language: String {
        get async throws {
            "ja"
        }
    }
}
