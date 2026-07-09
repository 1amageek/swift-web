/// One component of a route path pattern.
/// String literals use the conventional spelling: `":id"` is a parameter,
/// `"*"` matches any single component, `"**"` is a catchall.
public enum WebPathComponent: Sendable, Hashable, ExpressibleByStringLiteral, CustomStringConvertible {
    case constant(String)
    case parameter(String)
    case anything
    case catchall

    public init(stringLiteral value: String) {
        self.init(value)
    }

    public init(_ string: String) {
        if string == "*" {
            self = .anything
        } else if string == "**" {
            self = .catchall
        } else if string.hasPrefix(":") {
            self = .parameter(String(string.dropFirst()))
        } else {
            self = .constant(string)
        }
    }

    public var description: String {
        switch self {
        case .constant(let value):
            value
        case .parameter(let name):
            ":\(name)"
        case .anything:
            "*"
        case .catchall:
            "**"
        }
    }
}
