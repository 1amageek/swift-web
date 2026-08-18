#if hasFeature(Embedded) && !canImport(FoundationEssentials) && !canImport(Foundation)
import Testing
@testable import SwiftWebUI

@Suite
struct EmbeddedURLTests {
    @Test
    func preservesRelativeAndAbsoluteURLStrings() throws {
        let relative = try #require(URL(string: "/actors/counter"))
        let absolute = try #require(URL(string: "https://example.com/image.png"))

        #expect(relative.absoluteString == "/actors/counter")
        #expect(absolute.absoluteString == "https://example.com/image.png")
    }

    @Test
    func rejectsEmptyAndControlCharacterValues() {
        #expect(URL(string: "") == nil)
        #expect(URL(string: "https://example.com/\nheader") == nil)
    }
}
#endif
