import SwiftHTML

public struct StyleUtilityRegistry: Sendable {
    private let definitions: [StyleUtilityDefinition]

    public init(definitions: [StyleUtilityDefinition] = []) {
        self.definitions = definitions
    }

    public static let `default` = StyleUtilityRegistry()

    public func adding(_ definition: StyleUtilityDefinition) -> Self {
        StyleUtilityRegistry(definitions: definitions + [definition])
    }

    public func stylesheet(for className: StyleClass) -> Stylesheet {
        let rule = StyleUtilityRule(className: className)
        guard let style = style(for: rule.baseToken) else {
            preconditionFailure("Unknown style utility class: \(rule.baseToken)")
        }
        return rule.stylesheet(for: style)
    }

    private func style(for token: String) -> Style? {
        for definition in definitions {
            if let style = definition.resolve(token) {
                return style
            }
        }
        return Self.builtInStyle(for: token)
    }

    private static func builtInStyle(for token: String) -> Style? {
        switch token {
        case "block":
            return .display("block")
        case "inline-block":
            return .display("inline-block")
        case "inline":
            return .display("inline")
        case "flex":
            return .display("flex")
        case "inline-flex":
            return .display("inline-flex")
        case "grid":
            return .display("grid")
        case "hidden":
            return .display("none")
        case "contents":
            return .display("contents")
        default:
            break
        }

        if let value = arbitraryValue(token, prefix: "bg", property: "background") {
            return .background(value)
        }
        if let value = arbitraryValue(token, prefix: "text", property: "color") {
            return .color(value)
        }
        if let value = arbitraryValue(token, prefix: "text-size", property: "font-size") {
            return .fontSize(value)
        }
        if let value = arbitraryValue(token, prefix: "w", property: "width") {
            return .width(value)
        }
        if let value = arbitraryValue(token, prefix: "h", property: "height") {
            return .height(value)
        }
        if let value = arbitraryValue(token, prefix: "min-w", property: "min-width") {
            return .minWidth(value)
        }
        if let value = arbitraryValue(token, prefix: "max-w", property: "max-width") {
            return .maxWidth(value)
        }
        if let value = arbitraryValue(token, prefix: "min-h", property: "min-height") {
            return .minHeight(value)
        }
        if let value = arbitraryValue(token, prefix: "max-h", property: "max-height") {
            return .maxHeight(value)
        }
        if let value = arbitraryValue(token, prefix: "p", property: "padding") {
            return .padding(value)
        }
        if let value = arbitraryValue(token, prefix: "px", property: "padding-inline") {
            return .paddingInline(value)
        }
        if let value = arbitraryValue(token, prefix: "py", property: "padding-block") {
            return .paddingBlock(value)
        }
        if let value = arbitraryValue(token, prefix: "pt", property: "padding-top") {
            return .paddingTop(value)
        }
        if let value = arbitraryValue(token, prefix: "pr", property: "padding-right") {
            return .paddingRight(value)
        }
        if let value = arbitraryValue(token, prefix: "pb", property: "padding-bottom") {
            return .paddingBottom(value)
        }
        if let value = arbitraryValue(token, prefix: "pl", property: "padding-left") {
            return .paddingLeft(value)
        }
        if let value = arbitraryValue(token, prefix: "m", property: "margin") {
            return .margin(value)
        }
        if let value = arbitraryValue(token, prefix: "mx", property: "margin-inline") {
            return .marginInline(value)
        }
        if let value = arbitraryValue(token, prefix: "my", property: "margin-block") {
            return .marginBlock(value)
        }
        if let value = arbitraryValue(token, prefix: "mt", property: "margin-top") {
            return .marginTop(value)
        }
        if let value = arbitraryValue(token, prefix: "mr", property: "margin-right") {
            return .marginRight(value)
        }
        if let value = arbitraryValue(token, prefix: "mb", property: "margin-bottom") {
            return .marginBottom(value)
        }
        if let value = arbitraryValue(token, prefix: "ml", property: "margin-left") {
            return .marginLeft(value)
        }
        if let value = arbitraryValue(token, prefix: "grid-cols", property: "grid-template-columns") {
            return .gridTemplateColumns(value)
        }
        if let value = arbitraryValue(token, prefix: "opacity", property: "opacity") {
            return .opacity(value)
        }

        return nil
    }

    private static func arbitraryValue(_ token: String, prefix: String, property: String) -> String? {
        let marker = "\(prefix)-["
        guard token.hasPrefix(marker), token.hasSuffix("]") else { return nil }
        let start = token.index(token.startIndex, offsetBy: marker.count)
        let end = token.index(before: token.endIndex)
        let value = String(token[start..<end]).replacingOccurrences(of: "_", with: " ")
        guard StyleRegistry.isSafe(property: property, value: value) else {
            preconditionFailure("Rejected unsafe utility value: \(property): \(value)")
        }
        return value
    }
}

public func utility(_ className: StyleClass, registry: StyleUtilityRegistry = .default) -> Stylesheet {
    registry.stylesheet(for: className)
}

public struct StyleUtilityDefinition: Sendable {
    let resolve: @Sendable (String) -> Style?

    public init(_ resolve: @escaping @Sendable (String) -> Style?) {
        self.resolve = resolve
    }

    public static func token(_ token: String, style: Style) -> Self {
        Self { candidate in
            candidate == token ? style : nil
        }
    }

    public static func arbitrary(
        prefix: String,
        property: String,
        build: @escaping @Sendable (String) -> Style
    ) -> Self {
        Self { token in
            let marker = "\(prefix)-["
            guard token.hasPrefix(marker), token.hasSuffix("]") else { return nil }
            let start = token.index(token.startIndex, offsetBy: marker.count)
            let end = token.index(before: token.endIndex)
            let value = String(token[start..<end]).replacingOccurrences(of: "_", with: " ")
            guard StyleRegistry.isSafe(property: property, value: value) else {
                preconditionFailure("Rejected unsafe utility value: \(property): \(value)")
            }
            return build(value)
        }
    }
}
