import Testing

@testable import SwiftWebPackageGeneration

@Suite
struct SwiftWebClientPreviewStripperTests {
    @Test
    func stripsTopLevelPreview() {
        let source = """
            import SwiftHTML
            import SwiftWeb

            @Page("/")
            struct HomePage {
                var document: some HTMLDocument {
                    PageDocument(title: "Hello World") {
                        main {
                            h1 { "Hello World" }
                        }
                    }
                }
            }

            #Preview {
                HomePage().document.body
            }
            """
        let stripped = SwiftWebClientPreviewStripper.stripHTMLPreview(inSource: source)

        #expect(!stripped.contains("#Preview"))
        #expect(!stripped.contains("HomePage().document.body"))
        #expect(stripped.contains("struct HomePage"))
        #expect(stripped.contains("h1 { \"Hello World\" }"))
        #expect(stripped.contains("import SwiftHTML"))
    }

    @Test
    func stripsLegacyHTMLPreview() {
        let source = """
            import SwiftHTML

            #HTMLPreview {
                main { "legacy" }
            }
            """
        let stripped = SwiftWebClientPreviewStripper.stripHTMLPreview(inSource: source)
        #expect(!stripped.contains("#HTMLPreview"))
        #expect(stripped.contains("import SwiftHTML"))
    }

    @Test
    func leavesSourcesWithoutPreviewUnchanged() {
        let source = """
            struct Plain {
                var value = 1
            }
            """
        #expect(SwiftWebClientPreviewStripper.stripHTMLPreview(inSource: source) == source)
    }
}
