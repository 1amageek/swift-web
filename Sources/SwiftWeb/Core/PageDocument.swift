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
        let bodyAttributes: [HTMLAttribute] = metadata.bodyClass.map { [.class($0)] } ?? []
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
                    // Placeholder for atomic CSS rules collected during the render.
                    // HTMLResponse fills it after the body renders (collect-then-emit),
                    // so the rules sit in <head>, before the content they style.
                    style(.id("swui-atomic")) { "" }
                }
                Element("body", attributes: bodyAttributes) {
                    content
                }
            }
        }
    }
}
