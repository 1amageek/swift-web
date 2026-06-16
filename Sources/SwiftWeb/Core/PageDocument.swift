import SwiftHTML

public struct PageDocument<Content: HTML>: Component {
    private let metadata: PageMetadata
    private let content: Content

    public init(
        metadata: PageMetadata,
        @HTMLBuilder content: () -> Content
    ) {
        self.metadata = metadata
        self.content = content()
    }

    @HTMLBuilder
    public var body: some HTML {
        document {
            html(.lang(metadata.language)) {
                head {
                    meta(.charset("utf-8"))
                    meta(.name("viewport"), .content("width=device-width, initial-scale=1"))
                    title {
                        metadata.title
                    }
                    if let description = metadata.description {
                        meta(.name("description"), .content(description))
                    }
                }
                SwiftHTML.body {
                    content
                }
            }
        }
    }
}
