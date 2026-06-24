/// Result builder that assembles a block of source text from one or more string
/// statements, joining successive statements with newlines. `Code` uses it so
/// callers can supply source as a trailing closure holding a multi-line string
/// literal.
@resultBuilder
public enum StringBuilder {
    public static func buildBlock(_ components: String...) -> String {
        components.joined(separator: "\n")
    }

    public static func buildExpression(_ expression: String) -> String {
        expression
    }

    public static func buildOptional(_ component: String?) -> String {
        component ?? ""
    }

    public static func buildEither(first component: String) -> String {
        component
    }

    public static func buildEither(second component: String) -> String {
        component
    }

    public static func buildArray(_ components: [String]) -> String {
        components.joined(separator: "\n")
    }
}
