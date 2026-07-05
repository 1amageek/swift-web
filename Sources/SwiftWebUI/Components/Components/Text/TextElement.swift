import SwiftWebUITheme
public enum TextElement: Sendable, Equatable {
    case p
    case span
    case div
    case h1
    case h2
    case h3
    case h4
    case h5
    case h6
    case label
    case strong
    case em
    case small
    case code
    case pre
    case blockquote
    case custom(String)

    /// Resolves an HTML tag name to its element, so `Text.as("h1")` reads the
    /// same as `Text.as(.h1)`. Tags outside the known set render verbatim as a
    /// custom element rather than failing.
    public init(_ tag: String) {
        switch tag {
        case "p": self = .p
        case "span": self = .span
        case "div": self = .div
        case "h1": self = .h1
        case "h2": self = .h2
        case "h3": self = .h3
        case "h4": self = .h4
        case "h5": self = .h5
        case "h6": self = .h6
        case "label": self = .label
        case "strong": self = .strong
        case "em": self = .em
        case "small": self = .small
        case "code": self = .code
        case "pre": self = .pre
        case "blockquote": self = .blockquote
        default: self = .custom(tag)
        }
    }

    var tagName: String {
        switch self {
        case .p:
            "p"
        case .span:
            "span"
        case .div:
            "div"
        case .h1:
            "h1"
        case .h2:
            "h2"
        case .h3:
            "h3"
        case .h4:
            "h4"
        case .h5:
            "h5"
        case .h6:
            "h6"
        case .label:
            "label"
        case .strong:
            "strong"
        case .em:
            "em"
        case .small:
            "small"
        case .code:
            "code"
        case .pre:
            "pre"
        case .blockquote:
            "blockquote"
        case .custom(let name):
            name
        }
    }
}
