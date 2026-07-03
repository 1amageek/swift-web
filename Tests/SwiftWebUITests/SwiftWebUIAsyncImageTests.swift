import Foundation
import SwiftHTML
import SwiftWebUI
import Testing

@Suite
struct SwiftWebUIAsyncImageTests {
    @Test
    func rendersPlainImgForBasicInitializer() throws {
        let url = try #require(URL(string: "https://example.com/photo.jpg"))
        let rendered = AsyncImage(url: url).render()

        #expect(rendered.contains("<img"))
        #expect(rendered.contains("src=\"https://example.com/photo.jpg\""))
        #expect(rendered.contains("alt=\"\""))
        #expect(rendered.contains("decoding=\"async\""))
        // No wrapper and no srcset at scale 1: just the img.
        #expect(!rendered.contains("swui-async-image"))
        #expect(!rendered.contains("srcset"))
    }

    @Test
    func scaleLowersToSrcsetDensityDescriptor() throws {
        let url = try #require(URL(string: "https://example.com/photo.jpg"))
        let rendered = AsyncImage(url: url, scale: 2).render()

        #expect(rendered.contains("srcset=\"https://example.com/photo.jpg 2x\""))
    }

    @Test
    func placeholderStacksBeneathTheImage() throws {
        let url = try #require(URL(string: "https://example.com/photo.jpg"))
        let rendered = AsyncImage(url: url) { image in
            image
        } placeholder: {
            Text("Loading")
        }.render()

        #expect(rendered.contains("swui-async-image"))
        #expect(rendered.contains("Loading"))
        #expect(rendered.contains("<img"))
        // Source order puts the placeholder first so the image paints above it.
        let placeholderIndex = try #require(rendered.range(of: "Loading")?.lowerBound)
        let imageIndex = try #require(rendered.range(of: "<img")?.lowerBound)
        #expect(placeholderIndex < imageIndex)
    }

    @Test
    func contentClosureStylesTheImage() throws {
        let url = try #require(URL(string: "https://example.com/photo.jpg"))
        let rendered = AsyncImage(url: url) { image in
            image.clipShape(.rect(cornerRadius: 12))
        } placeholder: {
            Text("Loading")
        }.render()

        #expect(rendered.contains("swui-clip"))
    }

    @Test
    func nilURLRendersOnlyThePlaceholder() {
        let rendered = AsyncImage(url: nil) { image in
            image
        } placeholder: {
            Text("Loading")
        }.render()

        #expect(rendered.contains("Loading"))
        #expect(!rendered.contains("<img"))
    }

    @Test
    func nilURLWithoutPlaceholderRendersTheDefaultBox() {
        let rendered = AsyncImage(url: nil).render()

        #expect(rendered.contains("swui-async-image-default-placeholder"))
        #expect(!rendered.contains("<img"))
    }
}
