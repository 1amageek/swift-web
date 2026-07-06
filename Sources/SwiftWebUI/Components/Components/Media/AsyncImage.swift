#if canImport(FoundationEssentials)
import FoundationEssentials
#else
import Foundation
#endif
import SwiftWebUITheme
import SwiftHTML

/// Displays an image from a URL, mirroring SwiftUI's `AsyncImage`.
///
/// On the web this is just an `<img>`: the element is natively asynchronous,
/// so no loading machinery is added. `scale` lowers to a `srcset` density
/// descriptor, the platform's pixel-density contract. With a placeholder, the
/// image stacks above it in the same grid cell — the placeholder shows until
/// the image paints, and because the image is decorative (`alt=""`) a failed
/// load leaves the placeholder visible instead of a broken-image glyph.
public struct AsyncImage<ImageContent: HTML, Placeholder: HTML>: Component {
    private let url: URL?
    private let scale: Double
    private let content: @Sendable (Image) -> ImageContent
    private let placeholder: (@Sendable () -> Placeholder)?

    /// Displays the image, mirroring SwiftUI's `AsyncImage(url:scale:)`.
    public init(
        url: URL?,
        scale: Double = 1
    ) where ImageContent == Image, Placeholder == EmptyHTML {
        self.url = url
        self.scale = scale
        self.content = { image in image }
        self.placeholder = nil
    }

    /// Styles the image with `content` and shows `placeholder` beneath it
    /// until it paints (and if it never does), mirroring SwiftUI's
    /// `AsyncImage(url:scale:content:placeholder:)`.
    public init(
        url: URL?,
        scale: Double = 1,
        @HTMLBuilder content: @escaping @Sendable (Image) -> ImageContent,
        @HTMLBuilder placeholder: @escaping @Sendable () -> Placeholder
    ) {
        self.url = url
        self.scale = scale
        self.content = content
        self.placeholder = placeholder
    }

    @HTMLBuilder
    public var body: some HTML {
        if let url {
            if let placeholder {
                Element(
                    "div",
                    attributes: mergedAttributes(class: "swui-async-image", extra: [])
                ) {
                    placeholder()
                    content(Image(url: url, scale: scale))
                }
            } else {
                content(Image(url: url, scale: scale))
            }
        } else if let placeholder {
            // A nil URL never resolves, exactly like SwiftUI: only the
            // placeholder renders.
            placeholder()
        } else {
            div(.class("swui-async-image-default-placeholder")) {
                EmptyHTML()
            }
        }
    }
}
