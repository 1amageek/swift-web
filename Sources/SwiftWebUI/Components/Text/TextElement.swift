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
