import SwiftWebUITheme
import SwiftHTML

@available(*, deprecated, message: "Use the badge(_:) modifier on the labeled view, matching SwiftUI")
public struct Badge: WebUIAttributeComponent {
    private let text: String
    private let attributes: [HTMLAttribute]

    public init(_ text: String, _ attributes: HTMLAttribute...) {
        self.text = text
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        BadgePill(text, attributes: attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text: text, attributes: self.attributes + attributes)
    }

    private init(text: String, attributes: [HTMLAttribute]) {
        self.text = text
        self.attributes = attributes
    }
}
