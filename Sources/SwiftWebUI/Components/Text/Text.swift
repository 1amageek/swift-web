import SwiftHTML

public struct Text: WebUIAttributeComponent {
    private let value: String
    private let element: TextElement
    private let attributes: [HTMLAttribute]

    public init(
        _ value: String,
        as element: TextElement = .p,
        _ attributes: HTMLAttribute...
    ) {
        self.value = value
        self.element = element
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Element(element.tagName, attributes: mergedAttributes(class: className, extra: attributes)) {
            value
        }
    }

    public func `as`(_ element: TextElement) -> Self {
        Self(value, element: element, attributes: attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(value, element: element, attributes: self.attributes + attributes)
    }

    private init(_ value: String, element: TextElement, attributes: [HTMLAttribute]) {
        self.value = value
        self.element = element
        self.attributes = attributes
    }

    var plainValue: String {
        value
    }

    private var className: String {
        var classes = ["swui-text"]
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
