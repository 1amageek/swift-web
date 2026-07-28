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
        [.lang(metadata.language)]
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
        rawHTML("<!--swui-head-links-->")
        rawHTML("<!--swui-base-->")
        rawHTML("<!--swui-atomic-->")
        rawHTML("<!--swui-head-scripts-->")
    }

    @HTMLBuilder
    public var body: some Component {
        content
    }
}
