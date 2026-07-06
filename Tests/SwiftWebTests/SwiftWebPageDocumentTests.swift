import Foundation
import SwiftHTML
import SwiftWebStyle
import SwiftWebUI
import Testing
import SwiftWeb
@testable import SwiftWebCore

private struct PageDocumentRuntimeClientComponent: ClientComponent {
    @State private var value = 0

    var body: some HTML {
        button(.type(ButtonType.button), .onClick {
            value += 1
        }) {
            "Client \(value)"
        }
    }
}

private struct PageDocumentRuntimeStaticPage: Component {
    var body: some HTML {
        main {
            h1 { "Static heading" }
            div {
                PageDocumentRuntimeClientComponent()
            }
            footer { "Static footer" }
        }
    }
}

@Suite
struct SwiftWebPageDocumentTests {
    @Test
    func pageResponseAppliesDocumentStyleRootToBody() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            let response = try await VStack { Text("Styled") }
                .preferredColorScheme(.dark)
                .encodePageResponse(
                    for: request,
                    metadata: PageMetadata(title: "Styled")
                )
            let rendered = try #require(response.body.string)

            #expect(rendered.contains("<body class=\"swui-root\""))
            #expect(rendered.contains("data-color-scheme=\"dark\""))
            #expect(rendered.contains("data-theme=\""))
            #expect(rendered.contains("<style id=\"swui-base\">"))
            #expect(rendered.contains(".swui-root"))
            #expect(rendered.contains("<script id=\"swui-glass-refraction\""))
        }
    }

    @Test
    func pageResponseWithoutSchemeFollowsUserAgent() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            let response = try await Text("Styled").encodePageResponse(
                for: request,
                metadata: PageMetadata(title: "Styled")
            )
            let rendered = try #require(response.body.string)

            #expect(rendered.contains("<body class=\"swui-root\" data-theme=\""))
            #expect(!rendered.contains("<body class=\"swui-root\" data-color-scheme"))
        }
    }

    @Test
    func rawHTMLPageResponseSkipsDocumentStyleRoot() async throws {
        try await withApplication { application in
            let request = Request(application: application)
            let response = try await main { h1 { "Plain" } }.encodePageResponse(
                for: request,
                metadata: PageMetadata(title: "Plain")
            )
            let rendered = try #require(response.body.string)

            #expect(!rendered.contains("swui-root"))
            #expect(!rendered.contains("<script id=\"swui-glass-refraction\""))
        }
    }

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

            #expect(rendered.contains("<style id=\"swui-atomic\">.swui-"))
            #expect(rendered.contains("<div class=\"swui-spacer swui-"))
            #expect(rendered.contains("--swui-spacer-min-length: 12px"))
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
    func wasmPageResponsePrunesServerOnlyDOMFromClientRuntimeDescriptor() async throws {
        try await withApplication { application in
            application.swiftWebClientRuntime = .wasm(
                SwiftWebWasmClientRuntime(
                    manifestPath: "/assets/client.json",
                    runtimeAssetPath: "/assets/client.wasm"
                )
            )
            let request = Request(application: application)
            let response = try await PageDocumentRuntimeStaticPage().encodePageResponse(
                for: request,
                metadata: PageMetadata(title: "Runtime")
            )
            let rendered = try #require(response.body.string)
            let descriptor = try clientRuntimeDescriptor(in: rendered)
            let descriptorTexts = Set(descriptor.hydrationIndex.nodes.compactMap(\.text))

            #expect(rendered.contains("Static heading"))
            #expect(rendered.contains("Static footer"))
            #expect(descriptor.mode == .wasm)
            #expect(descriptor.hydrationIndex.components.count == 1)
            #expect(descriptor.hydrationIndex.handlers.count == 1)
            #expect(descriptor.hydrationIndex.nodes.contains { $0.text == "Client 0" })
            #expect(!descriptorTexts.contains("Static heading"))
            #expect(!descriptorTexts.contains("Static footer"))
        }
    }

    @Test
    func wasmPageResponseIncludesActorBindingsFromSceneScope() async throws {
        try await withApplication { application in
            application.swiftWebClientRuntime = .wasm(
                SwiftWebWasmClientRuntime(
                    manifestPath: "/assets/client.json",
                    runtimeAssetPath: "/assets/client.wasm"
                )
            )
            let binding = SwiftWebActorBindingRecord(
                contractKey: "Tests.CounterServiceProtocol",
                actorID: "counter-1"
            )
            let scope = SwiftWebActorBindingScope(records: [binding])
            let request = Request(application: application)
            let response = try await SwiftWebActorRenderContext.withValue(scope) {
                try await PageDocumentRuntimeStaticPage().encodePageResponse(
                    for: request,
                    metadata: PageMetadata(title: "Runtime")
                )
            }
            let rendered = try #require(response.body.string)
            let descriptor = try clientRuntimeDescriptor(in: rendered)

            #expect(descriptor.actorBindings == [binding])
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
        _ body: (TestWebApplication) async throws -> Void
    ) async throws {
        try await body(TestWebApplication())
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

    private func clientRuntimeDescriptor(in html: String) throws -> SwiftWebClientRuntimeDescriptor {
        let marker = "<script type=\"application/json\" id=\"client-runtime\">"
        let start = try #require(html.range(of: marker))
        let remainder = html[start.upperBound...]
        let end = try #require(remainder.range(of: "</script>"))
        let json = String(remainder[..<end.lowerBound])
        let data = Data(json.utf8)
        return try JSONDecoder().decode(SwiftWebClientRuntimeDescriptor.self, from: data)
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
