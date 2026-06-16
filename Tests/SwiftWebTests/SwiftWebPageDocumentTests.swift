import SwiftHTML
import SwiftWeb
import Testing

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
        #expect(rendered.contains("<body><main><h1>Counter</h1></main></body>"))
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
