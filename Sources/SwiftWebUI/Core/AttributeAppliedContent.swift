import SwiftHTML

public struct AttributeAppliedContent<Content: WebUIAttributeMutableHTML>: Component, WebUIAttributeMutableHTML {
    private let content: Content
    private let attributes: [HTMLAttribute]

    init(content: Content, attributes: [HTMLAttribute]) {
        self.content = content
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        content.addingAttributes(attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(content: content, attributes: self.attributes + attributes)
    }
}

extension WebUIAttributeMutableHTML {
    func applyingAttributes(_ attributes: [HTMLAttribute]) -> AttributeAppliedContent<Self> {
        AttributeAppliedContent(content: self, attributes: attributes)
    }
}
