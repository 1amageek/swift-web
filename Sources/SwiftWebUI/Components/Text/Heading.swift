import SwiftHTML

public enum HeadingLevel: Sendable {
    case page
    case section
    case subsection
    case level(Int)

    var tagClass: String {
        switch self {
        case .page:
            "swui-heading swui-heading-page"
        case .section:
            "swui-heading swui-heading-section"
        case .subsection:
            "swui-heading swui-heading-subsection"
        case .level:
            "swui-heading"
        }
    }

    var htmlLevel: Int {
        switch self {
        case .page:
            1
        case .section:
            2
        case .subsection:
            3
        case .level(let value):
            min(max(value, 1), 6)
        }
    }

    var textElement: TextElement {
        switch htmlLevel {
        case 1:
            .h1
        case 2:
            .h2
        case 3:
            .h3
        case 4:
            .h4
        case 5:
            .h5
        default:
            .h6
        }
    }
}

public struct Heading: WebUIAttributeComponent {
    private let text: String
    private let level: HeadingLevel
    private let attributes: [HTMLAttribute]

    public init(
        _ text: String,
        level: HeadingLevel = .section,
        _ attributes: HTMLAttribute...
    ) {
        self.text = text
        self.level = level
        self.attributes = attributes
    }

    @HTMLBuilder
    public var body: some HTML {
        Text(text, as: level.textElement)
            .class(level.tagClass)
            .addingAttributes(attributes)
    }

    public func addingAttributes(_ attributes: [HTMLAttribute]) -> Self {
        Self(text, level: level, attributes: self.attributes + attributes)
    }

    private init(_ text: String, level: HeadingLevel, attributes: [HTMLAttribute]) {
        self.text = text
        self.level = level
        self.attributes = attributes
    }
}
