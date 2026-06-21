import SwiftHTML

public struct Text: WebUIAttributeComponent {
    private let value: String
    private let element: TextElement
    private let tone: TextTone
    private let attributes: [HTMLAttribute]

    public init(
        _ value: String,
        as element: TextElement = .p,
        tone: TextTone = .normal,
        _ attributes: HTMLAttribute...
    ) {
        self.value = value
        self.element = element
        self.tone = tone
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(element.tagName, attributes: mergedAttributes(class: className, extra: attributes)) {
            value
        }
    }

    public func `as`(_ element: TextElement) -> Self {
        Self(value, element: element, tone: tone, attributes: attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(value, element: element, tone: tone, attributes: self.attributes + attributes)
    }

    private init(_ value: String, element: TextElement, tone: TextTone, attributes: [HTMLAttribute]) {
        self.value = value
        self.element = element
        self.tone = tone
        self.attributes = attributes
    }

    var plainValue: String {
        value
    }

    private var className: String {
        var classes: [String]
        switch tone {
        case .normal:
            classes = ["swui-text"]
        case .muted:
            classes = ["swui-text", "swui-text-muted"]
        }

        switch element {
        case .code:
            classes.append("swui-inline-code")
        case .pre:
            classes.append("swui-preformatted")
        default:
            break
        }

        return classes.joined(separator: " ")
    }
}
