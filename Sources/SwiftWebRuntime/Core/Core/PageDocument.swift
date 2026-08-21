import SwiftHTML

/// SwiftWeb's metadata-aware concrete HTML document.
///
/// Return a custom ``HTMLDocument`` from a page when direct control of the
/// document head is required.
public struct PageDocument<Content: Component>: HTMLDocument {
    private let metadata: PageMetadata
    private let content: Content

    public init(
        metadata: PageMetadata,
        @HTMLBuilder content: () -> Content
    ) {
        self.metadata = metadata
        self.content = content()
    }

    public init(
        title: String,
        description: String? = nil,
        language: String = "en",
        bodyClass: String? = nil,
        @HTMLBuilder content: () -> Content
    ) {
        self.init(
            metadata: PageMetadata(
                title: title,
                description: description,
                language: language,
                bodyClass: bodyClass
            ),
            content: content
        )
    }

    public var htmlAttributes: [HTMLAttribute] {
        var attributes: [HTMLAttribute] = [.lang(metadata.language)]
        if metadata.openGraph != nil {
            attributes.append(.attribute("prefix", "og: https://ogp.me/ns#"))
        }
        return attributes
    }

    public var bodyAttributes: [HTMLAttribute] {
        metadata.bodyClass.map { [.class($0)] } ?? []
    }

    @HTMLBuilder
    public var head: some Component {
        meta(.charset("utf-8"))
        meta(.name("viewport"), .content("width=device-width, initial-scale=1"))
        title {
            metadata.title
        }
        if let description = metadata.description {
            meta(.name("description"), .content(description))
        }
        if let openGraph = metadata.openGraph {
            openGraphTags(openGraph)
        }
        rawHTML("<!--swui-head-links-->")
        rawHTML("<!--swui-base-->")
        rawHTML("<!--swui-atomic-->")
        rawHTML("<!--swui-head-scripts-->")
    }

    @HTMLBuilder
    public var body: some Component {
        content
    }

    @HTMLBuilder
    private func openGraphTags(_ openGraph: OpenGraphMetadata) -> some Component {
        openGraphPageTags(openGraph)
        openGraphLocaleTags(openGraph)
        openGraphImageTags(openGraph.image)
    }

    @HTMLBuilder
    private func openGraphPageTags(_ openGraph: OpenGraphMetadata) -> some Component {
        meta(.attribute("property", "og:title"), .content(metadata.title))
        meta(.attribute("property", "og:type"), .content(openGraph.type))
        meta(.attribute("property", "og:url"), .content(openGraph.url))
        if let description = metadata.description {
            meta(.attribute("property", "og:description"), .content(description))
        }
        if let siteName = openGraph.siteName {
            meta(.attribute("property", "og:site_name"), .content(siteName))
        }
    }

    @HTMLBuilder
    private func openGraphLocaleTags(_ openGraph: OpenGraphMetadata) -> some Component {
        if let locale = openGraph.locale {
            meta(.attribute("property", "og:locale"), .content(locale))
        }
        for locale in openGraph.alternateLocales {
            meta(.attribute("property", "og:locale:alternate"), .content(locale))
        }
    }

    @HTMLBuilder
    private func openGraphImageTags(_ image: OpenGraphImage) -> some Component {
        meta(.attribute("property", "og:image"), .content(image.url))
        if let secureURL = image.secureURL {
            meta(.attribute("property", "og:image:secure_url"), .content(secureURL))
        }
        if let mediaType = image.mediaType {
            meta(.attribute("property", "og:image:type"), .content(mediaType))
        }
        if let width = image.width {
            meta(.attribute("property", "og:image:width"), .content(String(width)))
        }
        if let height = image.height {
            meta(.attribute("property", "og:image:height"), .content(String(height)))
        }
        meta(.attribute("property", "og:image:alt"), .content(image.alt))
    }
}
