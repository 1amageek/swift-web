import SwiftHTML

public struct Badge: WebUIAttributeComponent {
    private let text: String
    private let attributes: [HTMLAttribute]

    public init(_ text: String, _ attributes: HTMLAttribute...) {
        self.text = text
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("span", attributes: mergedAttributes(class: "swui-badge", extra: attributes)) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, attributes: self.attributes + attributes)
    }

    private init(_ text: String, attributes: [HTMLAttribute]) {
        self.text = text
        self.attributes = attributes
    }
}
