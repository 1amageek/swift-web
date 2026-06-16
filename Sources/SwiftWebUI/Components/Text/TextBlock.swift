import SwiftHTML

public enum TextTone: Sendable {
    case normal
    case muted
}

public struct TextBlock: WebUIAttributeComponent {
    private let text: String
    private let tone: TextTone
    private let attributes: [HTMLAttribute]

    public init(_ text: String, tone: TextTone = .normal, _ attributes: HTMLAttribute...) {
        self.text = text
        self.tone = tone
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element("p", attributes: mergedAttributes(class: className, extra: attributes)) {
            text
        }
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, tone: tone, attributes: self.attributes + attributes)
    }

    private init(_ text: String, tone: TextTone, attributes: [HTMLAttribute]) {
        self.text = text
        self.tone = tone
        self.attributes = attributes
    }

    private var className: String {
        switch tone {
        case .normal:
            "swui-text"
        case .muted:
            "swui-text swui-text-muted"
        }
    }
}
