import Foundation
import ActorSystemCore
import SwiftHTML
import SwiftWebStyle
import SwiftWebUI
import Testing
import SwiftWeb
@testable import SwiftWebCore

private struct PageDocumentRuntimeClientComponent: ClientComponent {
    @State private var value = 0

    var content: some Component {
        button(.type(ButtonType.button), .onClick {
            value += 1
        }) {
            "Client \(value)"
        }
    }
}

private struct PageDocumentRuntimeStaticPage: Component {
    var content: some Component {
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
        try await withRuntime { runtime in
            let request = Request(runtime: runtime)
            let response = try await PageDocument(title: "Styled") {
                VStack { Text("Styled") }
                    .preferredColorScheme(.dark)
            }
            .encodeResponse(for: request)
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
        try await withRuntime { runtime in
            let request = Request(runtime: runtime)
            let response = try await PageDocument(title: "Styled") {
                Text("Styled")
            }
            .encodeResponse(for: request)
            let rendered = try #require(response.body.string)

            #expect(rendered.contains("<body class=\"swui-root\" data-theme=\""))
            #expect(!rendered.contains("<body class=\"swui-root\" data-color-scheme"))
        }
    }

    @Test
    func rawHTMLPageResponseSkipsDocumentStyleRoot() async throws {
        try await withRuntime { runtime in
            let request = Request(runtime: runtime)
            let response = try await PageDocument(title: "Plain") {
                main { h1 { "Plain" } }
            }
            .encodeResponse(for: request)
            let rendered = try #require(response.body.string)

            #expect(!rendered.contains("swui-root"))
            #expect(!rendered.contains("<script id=\"swui-glass-refraction\""))
        }
    }

    @Test
    func staticAndLoadedPagesResolveDocuments() async throws {
        let staticHTML = try await StaticDocumentPage().resolveDocument().render()
        let loadedHTML = try await LoadedDocumentPage().resolveDocument().render()
        let macroLoadedHTML = try await MacroLoadedDocumentPage().resolveDocument().render()

        #expect(staticHTML.contains("<title>Static</title>"))
        #expect(loadedHTML.contains("<title>Loaded</title>"))
        #expect(loadedHTML.contains("<main>Database value</main>"))
        #expect(macroLoadedHTML.contains("<main>Macro database value</main>"))
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
        try await withRuntime { runtime in
            let request = Request(runtime: runtime)
            let response = try await PageDocument(title: "Atomic") {
                Spacer(minLength: 12)
            }
            .encodeResponse(for: request)
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
        try await withRuntime { runtime in
            let request = Request(runtime: runtime)
            let response = try await PageDocument(title: "Raw Atomic") {
                div(.class("raw-element"), .style(.minWidth("14px"))) {
                    "Raw"
                }
            }
            .encodeResponse(for: request)
            let rendered = try #require(response.body.string)

            #expect(rendered.contains("<style id=\"swui-atomic\">.swui-minw-14px-"))
            #expect(rendered.contains("<div class=\"raw-element swui-minw-14px-"))
            #expect(!rendered.contains("style=\""))
        }
    }

    @Test
    func wasmPageResponsePrunesServerOnlyDOMFromClientRuntimeDescriptor() async throws {
        try await withRuntime { runtime in
            runtime.swiftWebClientRuntime = .wasm(
                SwiftWebWasmClientRuntime(
                    manifestPath: "/assets/client.json",
                    runtimeAssetPath: "/assets/client.wasm"
                )
            )
            let request = Request(runtime: runtime)
            let response = try await PageDocument(title: "Runtime") {
                PageDocumentRuntimeStaticPage()
            }
            .encodeResponse(for: request)
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
        try await withRuntime { runtime in
            runtime.swiftWebClientRuntime = .wasm(
                SwiftWebWasmClientRuntime(
                    manifestPath: "/assets/client.json",
                    runtimeAssetPath: "/assets/client.wasm"
                )
            )
            let binding = SwiftWebActorBindingRecord(
                contractKey: "Tests.CounterServiceProtocol",
                actorID: ActorAddress(
                    type: ActorTypeID(high: 1, low: 2),
                    identity: "counter-1"
                )
            )
            let scope = SwiftWebActorBindingScope(records: [binding])
            let request = Request(runtime: runtime)
            let response = try await SwiftWebActorRenderContext.withValue(scope) {
                try await PageDocument(title: "Runtime") {
                    PageDocumentRuntimeStaticPage()
                }
                .encodeResponse(for: request)
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

    private func withRuntime(
        _ body: (TestWebRuntime) async throws -> Void
    ) async throws {
        try await body(TestWebRuntime())
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

private struct StaticDocumentPage: StaticPage {
    var document: some HTMLDocument {
        PageDocument(title: "Static") {
            main { "Static value" }
        }
    }
}

private struct LoadedDocumentPage: LoadedPage {
    func load() async throws -> String {
        "Database value"
    }

    func document(_ model: String) -> some HTMLDocument {
        PageDocument(title: "Loaded") {
            main { model }
        }
    }
}

@Page("/macro-loaded-document")
private struct MacroLoadedDocumentPage {
    func load() async throws -> String {
        "Macro database value"
    }

    func document(_ model: String) -> some HTMLDocument {
        PageDocument(title: "Macro Loaded") {
            main { model }
        }
    }
}
